[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Generate', 'Check', 'Preview', 'Install', 'Verify')][string] $Mode,
    [Parameter(Mandatory)][string] $ActivationPath,
    [Parameter(Mandatory)][string] $TargetRoot,
    [switch] $AcceptDeployment,
    [string] $ReportPath
)

# Plan 06 P9: a deliberately small activation renderer. It substitutes only @@NAME@@ tokens,
# generates candidates below artifacts/, validates them through declared public commands, and
# requires an explicit switch before it writes an activated copy.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$utf8 = [Text.UTF8Encoding]::new($false)
$root = [IO.Path]::GetFullPath($TargetRoot)
if (-not [IO.Directory]::Exists($root)) { throw "TargetRoot does not exist: $root" }
$rootPrefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar

function Normalize([string] $text) { return $text.Replace("`r`n", "`n").Replace("`r", "`n") }
function Safe-Relative([string] $path) {
    $value = $path.Replace('\', '/')
    if ([string]::IsNullOrWhiteSpace($value) -or $value.StartsWith('/') -or $value -match '^[A-Za-z]:' -or
        @($value -split '/' | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0 -or $value -match '[*?]') {
        throw "Unsafe repository-relative path: $path"
    }
    return $value
}
function Full([string] $relative) {
    $safe = Safe-Relative $relative
    $path = [IO.Path]::GetFullPath((Join-Path $root $safe))
    if (-not $path.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes TargetRoot: $relative" }
    return $path
}
function Read-Text([string] $relative) {
    $path = Full $relative
    if (-not [IO.File]::Exists($path)) { throw "Missing activation input: $relative" }
    return Normalize ([IO.File]::ReadAllText($path))
}
function Hash-Text([string] $text) {
    $bytes = $utf8.GetBytes((Normalize $text))
    return ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))).ToLowerInvariant()
}
function Write-Text([string] $relative, [string] $text) {
    $path = Full $relative
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
    [IO.File]::WriteAllText($path, (Normalize $text), $utf8)
}

$activationRelative = if ([IO.Path]::IsPathRooted($ActivationPath)) {
    $activationFull = [IO.Path]::GetFullPath($ActivationPath)
    if (-not $activationFull.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'ActivationPath must stay under TargetRoot.' }
    $activationFull.Substring($rootPrefix.Length).Replace('\', '/')
} else { Safe-Relative $ActivationPath }
$activationFile = Full $activationRelative
if (-not [IO.File]::Exists($activationFile)) { throw "Activation manifest is missing: $activationRelative" }
$activation = Get-Content -LiteralPath $activationFile -Raw | ConvertFrom-Json -AsHashtable -Depth 50
if ([int]$activation.formatVersion -ne 1 -or @($activation.artifacts).Count -eq 0) { throw 'Unsupported or empty activation manifest.' }

if ($activation.Contains('schema')) {
    $schema = Full ([string]$activation.schema)
    if (-not (Test-Json -Path $activationFile -SchemaFile $schema -ErrorAction Stop)) { throw "Activation manifest does not match $($activation.schema)." }
}

$rendered = [ordered]@{}
foreach ($artifact in @($activation.artifacts)) {
    $template = Read-Text ([string]$artifact.template)
    $variablesText = ''
    $variables = [ordered]@{}
    if ($artifact.Contains('variables')) {
        if (-not $artifact.Contains('variablesSchema')) { throw "Artifact '$($artifact.id)' declares variables without variablesSchema." }
        $variablesFile = Full ([string]$artifact.variables)
        $variablesSchema = Full ([string]$artifact.variablesSchema)
        if (-not (Test-Json -Path $variablesFile -SchemaFile $variablesSchema -ErrorAction Stop)) { throw "Variables for '$($artifact.id)' do not match $($artifact.variablesSchema)." }
        $variablesText = Read-Text ([string]$artifact.variables)
        $parsed = $variablesText | ConvertFrom-Json -AsHashtable -Depth 20
        foreach ($key in $parsed.Keys) {
            if ($key -cnotmatch '^[A-Z][A-Z0-9_]*$') { throw "Invalid stable variable name '$key' in $($artifact.variables)." }
            $variables[$key] = [string]$parsed[$key]
        }
    }
    $body = $template
    foreach ($key in $variables.Keys) { $body = $body.Replace("@@$key@@", [string]$variables[$key]) }
    $unknown = [Regex]::Matches($body, '@@[A-Z][A-Z0-9_]*@@') | ForEach-Object Value | Sort-Object -Unique
    if (@($unknown).Count -gt 0) { throw "Unbound template variables for $($artifact.id): $($unknown -join ', ')" }
    $sourceMaterial = "template=$($artifact.template)`n$template"
    if ($artifact.Contains('variables')) { $sourceMaterial += "`nvariables=$($artifact.variables)`n$variablesText" }
    $hash = Hash-Text $sourceMaterial
    switch ([string]$artifact.kind) {
        'full-file' {
            $text = "# Generated from: $($artifact.template)`n# Source-SHA256: $hash`n$body"
        }
        'managed-block' {
            $marker = [string]$artifact.marker
            if ($marker -cnotmatch '^[A-Za-z0-9_.-]+$') { throw "Invalid managed block marker: $marker" }
            $text = "# BEGIN V3 MANAGED: $marker`n# Generated from: $($artifact.template)`n# Source-SHA256: $hash`n$($body.TrimEnd("`n"))`n# END V3 MANAGED: $marker`n"
        }
        default { throw "Unknown activation artifact kind '$($artifact.kind)'." }
    }
    $rendered[[string]$artifact.id] = [ordered]@{ artifact = $artifact; body = $body; sourceHash = $hash; text = $text }
}

function Assert-Candidate {
    param([hashtable] $item)
    $candidate = [string]$item.artifact.candidate
    $candidatePath = Full $candidate
    if (-not [IO.File]::Exists($candidatePath)) { throw "Missing generated candidate: $candidate" }
    if ((Read-Text $candidate) -cne $item.text) { throw "Generated candidate drift: $candidate" }
}

function Invoke-Validators {
    if (-not $activation.Contains('validators')) { return }
    $commandsPath = Full ([string]$activation.commandsManifest)
    $commands = Get-Content -LiteralPath $commandsPath -Raw | ConvertFrom-Json -AsHashtable -Depth 30
    foreach ($validator in @($activation.validators)) {
        $command = @($commands.commands | Where-Object { $_.id -eq $validator.commandId })
        if ($command.Count -ne 1) { throw "Validator '$($validator.id)' names an unknown or duplicate command '$($validator.commandId)'." }
        if ($command[0].kind -ne 'public') { throw "Validator '$($validator.id)' may call only a public command." }
        $entry = Full ([string]$command[0].entryPoint)
        $declaredArguments = @($validator.arguments | ForEach-Object { [string]$_ })
        if ($declaredArguments.Count % 2 -ne 0) { throw "Validator '$($validator.id)' arguments must be name/value pairs." }
        $arguments = @('-NoProfile', '-File', $entry, '-TargetRoot', $root)
        for ($i = 0; $i -lt $declaredArguments.Count; $i += 2) {
            $name = $declaredArguments[$i]
            if ($name -cnotmatch '^-[A-Za-z][A-Za-z0-9]*$') { throw "Validator '$($validator.id)' has an invalid parameter name '$name'." }
            $arguments += @($name, $declaredArguments[$i + 1])
        }
        & pwsh @arguments
        if ($LASTEXITCODE) { throw "Validator '$($validator.id)' failed with exit code $LASTEXITCODE." }
    }
}

function Get-Comparison {
    param([hashtable] $item)
    $artifact = $item.artifact
    $targetPath = Full ([string]$artifact.target)
    if (-not [IO.File]::Exists($targetPath)) { return [ordered]@{ status = 'missing'; detail = 'activated target does not exist' } }
    $target = Normalize ([IO.File]::ReadAllText($targetPath))
    if ($artifact.kind -eq 'full-file') {
        if ($target -ceq $item.text) { return [ordered]@{ status = 'current'; detail = 'candidate and activated copy are byte-identical' } }
        if ($target.TrimEnd("`n") -ceq $item.body.TrimEnd("`n")) { return [ordered]@{ status = 'legacy-equivalent'; detail = 'body is identical; activated copy predates the provenance header' } }
        return [ordered]@{ status = 'drift'; detail = 'activated content differs from the rendered template' }
    }
    $start = "# BEGIN V3 MANAGED: $($artifact.marker)"
    $end = "# END V3 MANAGED: $($artifact.marker)"
    $pattern = "(?ms)^$([Regex]::Escape($start))`n.*?^$([Regex]::Escape($end))`n?"
    $match = [Regex]::Match($target, $pattern)
    if ($match.Success) {
        if ((Normalize $match.Value).TrimEnd("`n") -ceq $item.text.TrimEnd("`n")) { return [ordered]@{ status = 'current'; detail = 'managed block is current' } }
        return [ordered]@{ status = 'drift'; detail = 'managed block differs from the rendered candidate' }
    }
    if ($target.Contains($item.body.TrimEnd("`n"))) { return [ordered]@{ status = 'legacy-equivalent'; detail = 'managed lines are equivalent but not yet marker-owned' } }
    return [ordered]@{ status = 'missing'; detail = 'managed block is not activated' }
}

function Install-Item {
    param([hashtable] $item)
    $artifact = $item.artifact
    $targetPath = Full ([string]$artifact.target)
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($targetPath))
    if ($artifact.kind -eq 'full-file') { [IO.File]::WriteAllText($targetPath, $item.text, $utf8); return }
    $target = if ([IO.File]::Exists($targetPath)) { Normalize ([IO.File]::ReadAllText($targetPath)) } else { '' }
    $start = "# BEGIN V3 MANAGED: $($artifact.marker)"
    $end = "# END V3 MANAGED: $($artifact.marker)"
    $pattern = "(?ms)^$([Regex]::Escape($start))`n.*?^$([Regex]::Escape($end))`n?"
    if ([Regex]::IsMatch($target, $pattern)) { $target = [Regex]::Replace($target, $pattern, $item.text, 1) }
    elseif ($target.Contains($item.body.TrimEnd("`n"))) { $target = $target.Replace($item.body.TrimEnd("`n"), $item.text.TrimEnd("`n")) }
    else { $target = $target.TrimEnd("`n") + $(if ($target.Length) { "`n`n" } else { '' }) + $item.text }
    [IO.File]::WriteAllText($targetPath, $target, $utf8)
}

if ($Mode -eq 'Generate') {
    foreach ($item in $rendered.Values) { Write-Text ([string]$item.artifact.candidate) ([string]$item.text) }
    Write-Host "Generated $($rendered.Count) activation candidates."
    exit 0
}

foreach ($item in $rendered.Values) { Assert-Candidate $item }
if ($Mode -eq 'Check') {
    Invoke-Validators
    Write-Host "Checked $($rendered.Count) activation candidates and declared validators."
    exit 0
}

$comparisons = @($rendered.Values | ForEach-Object {
    $comparison = Get-Comparison $_
    [ordered]@{ id = $_.artifact.id; candidate = $_.artifact.candidate; target = $_.artifact.target; sourceHash = $_.sourceHash; status = $comparison.status; detail = $comparison.detail }
})
if ($Mode -eq 'Install') {
    if (-not $AcceptDeployment) { throw 'Install requires -AcceptDeployment.' }
    Invoke-Validators
    foreach ($item in $rendered.Values) { Install-Item $item }
    $comparisons = @($rendered.Values | ForEach-Object {
        $comparison = Get-Comparison $_
        [ordered]@{ id = $_.artifact.id; candidate = $_.artifact.candidate; target = $_.artifact.target; sourceHash = $_.sourceHash; status = $comparison.status; detail = $comparison.detail }
    })
}

$acceptable = if ($Mode -eq 'Preview') { @('current', 'legacy-equivalent') } else { @('current') }
$failed = @($comparisons | Where-Object { $_.status -notin $acceptable })
$report = [ordered]@{ formatVersion = 1; mode = $Mode.ToLowerInvariant(); activation = $activationRelative; artifacts = $comparisons; status = if ($failed.Count) { 'fail' } else { 'pass' } }
if ($ReportPath) {
    $reportFile = if ([IO.Path]::IsPathRooted($ReportPath)) { [IO.Path]::GetFullPath($ReportPath) } else { Full $ReportPath }
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($reportFile))
    [IO.File]::WriteAllText($reportFile, ($report | ConvertTo-Json -Depth 20), $utf8)
}
foreach ($entry in $comparisons) { Write-Host "$($entry.status.ToUpperInvariant()) $($entry.id): $($entry.detail)" }
if ($failed.Count) { exit 1 }
Write-Host "$Mode passed for $($comparisons.Count) activation artifacts."
