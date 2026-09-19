[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Init', 'Analyze')][string] $Mode,
    [Parameter(Mandatory)][string] $TargetRoot,
    [string] $ProfileDirectory,
    [string] $ProfileLayoutPath,
    [string] $ProfileRepositoryRoot,
    [string] $OutputDirectory,
    [string] $EvidenceDirectory,
    [ValidatePattern('^[a-z0-9][a-z0-9-]*$')][string] $PackageId = 'v3',
    [string] $ProjectId,
    [string] $TargetFramework,
    [string[]] $ExcludePaths = @()
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($TargetRoot)
if (-not [IO.Directory]::Exists($root)) { throw "TargetRoot does not exist: $root" }
$rootPrefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$utf8 = [Text.UTF8Encoding]::new($false)
function Resolve-UnderRoot([string] $value) {
    $full = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($value)) { $value } else { Join-Path $root $value }))
    if (-not $full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path must stay under TargetRoot: $value" }
    return $full
}
function Write-Lf([string] $path, [string] $value) {
    [void] [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
    [IO.File]::WriteAllText($path, $value.Replace("`r`n", "`n").Replace("`r", "`n").TrimEnd("`n") + "`n", $utf8)
}
function Write-Json([string] $path, [object] $value) { Write-Lf $path (ConvertTo-Json -InputObject $value -Depth 100) }
function Relative([string] $path) { return [IO.Path]::GetRelativePath($root, $path).Replace('\', '/') }
function Hash-File([string] $path) { return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($path))).ToLowerInvariant() }

if ($Mode -eq 'Init') {
    if ($ProfileLayoutPath) { throw 'Init creates a legacy directory profile and does not accept ProfileLayoutPath.' }
    if (-not $ProfileDirectory -or -not $ProjectId -or -not $TargetFramework) { throw 'Init requires ProfileDirectory, ProjectId and TargetFramework.' }
    if ($ProjectId -cnotmatch '^[a-z][a-z0-9-]+$') { throw 'ProjectId must match the profile contract.' }
    if ($TargetFramework -cnotmatch '^net[0-9]+\.0$') { throw 'TargetFramework must be a netN.0 target.' }
    $profileRoot = Resolve-UnderRoot $ProfileDirectory
    if ([IO.Directory]::Exists($profileRoot) -or [IO.File]::Exists($profileRoot)) { throw "Refusing to overwrite profile: $profileRoot" }
    [void] [IO.Directory]::CreateDirectory((Join-Path $profileRoot 'rules'))
    Write-Json (Join-Path $profileRoot 'profile.json') ([ordered]@{ formatVersion = 1; projectId = $ProjectId })
    Write-Json (Join-Path $profileRoot 'project-map.json') ([ordered]@{
        formatVersion = 1
        areas = @([ordered]@{ id = 'UNREVIEWED'; pathPattern = 'unreviewed/**'; layer = 'UNREVIEWED'; owner = 'UNREVIEWED'; similarImplementationRoot = 'unreviewed'; focusedCommands = @('review-test') })
        riskTriggers = @()
    })
    Write-Json (Join-Path $profileRoot 'tech-stack.json') ([ordered]@{
        formatVersion = 1; targetLanguages = @('C#')
        commands = @([ordered]@{ id = 'review-test'; executable = 'dotnet'; arguments = @('test'); workingDirectory = '.' })
        testProject = [ordered]@{ targetFramework = $TargetFramework; framework = 'xunit' }
    })
    Write-Json (Join-Path $profileRoot 'rules/ARCH.UNCONFIGURED.json') ([ordered]@{
        formatVersion = 1; id = 'ARCH.UNCONFIGURED'; title = 'Replace with reviewed target rules'
        kind = 'none'; enforcement = 'advisory'; coverage = 'none'
        authority = 'Scaffold placeholder; no architecture policy is inferred'
        appliesTo = @('unreviewed/**')
    })
    Write-Lf (Join-Path $profileRoot 'README.md') @'
# Unreviewed guard profile

This scaffold is intentionally incomplete. Replace the placeholder area, owner, focused command, language and advisory rule with evidence reviewed for this repository. `Validate` checks shape, but `Pre` cannot map real paths and generated `Test` requires a supported blocking detector with a negative fixture. Run Analyze for evidence, review the profile, then Render/Check the Markdown views. Do not enable a required CI check from this scaffold.
'@
    Write-Host "Created unreviewed profile: $profileRoot"
    exit 0
}

if (-not $OutputDirectory) { $OutputDirectory = "artifacts/guards/$PackageId/analysis" }
$output = Resolve-UnderRoot $OutputDirectory
if ($output -eq $root) { throw 'OutputDirectory must not be TargetRoot.' }
function Match-Glob([string] $path, [string] $pattern) {
    $p = $pattern.Replace('\', '/')
    if ($p.StartsWith('/') -or $p -match '^[A-Za-z]:' -or $p -match '(^|/)\.\.(/|$)') { throw "Unsafe exclusion pattern: $pattern" }
    $regex = [Text.StringBuilder]::new('^')
    for ($i = 0; $i -lt $p.Length; $i++) {
        if ($i + 2 -lt $p.Length -and $p.Substring($i, 3) -eq '**/') { [void] $regex.Append('(?:.*/)?'); $i += 2 }
        elseif ($i + 1 -lt $p.Length -and $p.Substring($i, 2) -eq '**') { [void] $regex.Append('.*'); $i++ }
        elseif ($p[$i] -eq '*') { [void] $regex.Append('[^/]*') }
        elseif ($p[$i] -eq '?') { [void] $regex.Append('[^/]') }
        else { [void] $regex.Append([Regex]::Escape([string] $p[$i])) }
    }
    [void] $regex.Append('$')
    return [Regex]::IsMatch($path, $regex.ToString(), [Text.RegularExpressions.RegexOptions]::IgnoreCase)
}
foreach ($exclude in $ExcludePaths) { [void] (Match-Glob 'sample' $exclude) }
$skipNames = @('.git', '.vs', 'bin', 'obj', 'node_modules', 'artifacts', 'generated')
$files = [Collections.Generic.List[string]]::new()
$queue = [Collections.Generic.Queue[string]]::new()
$queue.Enqueue($root)
while ($queue.Count -gt 0) {
    $directory = $queue.Dequeue()
    foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force)) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
        $relative = Relative $item.FullName
        if (@($ExcludePaths | Where-Object { Match-Glob $relative $_ }).Count -gt 0) { continue }
        if ($item.PSIsContainer) {
            if ($item.Name -in $skipNames) { continue }
            $itemPrefix = $item.FullName.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
            if ($output.StartsWith($itemPrefix, [StringComparison]::OrdinalIgnoreCase) -or $item.FullName -eq $output) {
                # Only skip the output directory itself, not its ancestors.
                if ($item.FullName -eq $output) { continue }
            }
            $queue.Enqueue($item.FullName)
        }
        else {
            if ($files.Count -ge 50000) { throw 'Analysis exceeded 50000 files; narrow ExcludePaths.' }
            $files.Add($item.FullName)
        }
    }
}
$projects = @()
$manifests = @()
$workflows = @()
$guidance = @()
foreach ($file in @($files | Sort-Object { Relative $_ })) {
    $path = Relative $file
    $name = [IO.Path]::GetFileName($file)
    if ($name.EndsWith('.csproj', [StringComparison]::OrdinalIgnoreCase)) {
        [xml] $xml = [IO.File]::ReadAllText($file)
        $frameworks = @($xml.SelectNodes("//*[local-name()='TargetFramework' or local-name()='TargetFrameworks']") | ForEach-Object { $_.InnerText } | Sort-Object -Unique)
        $references = @($xml.SelectNodes("//*[local-name()='ProjectReference']") | ForEach-Object {
            $include = [string] $_.GetAttribute('Include')
            $resolved = ''
            if ($include -and $include -notmatch '[\$*?]') {
                $full = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetDirectoryName($file)) $include))
                if ($full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) { $resolved = Relative $full }
            }
            [ordered]@{ include = $include; resolvedPath = $resolved }
        })
        $role = if ($path -match '(^|/)fixtures/') { 'fixture' } elseif ($path -match '(^|/)tests/' -or $name -match '\.Tests\.csproj$') { 'test' } else { 'source' }
        $projects += [ordered]@{ path = $path; role = $role; sha256 = Hash-File $file; frameworks = $frameworks; projectReferences = $references }
    }
    elseif ($name -eq 'package.json') {
        $json = [IO.File]::ReadAllText($file) | ConvertFrom-Json -AsHashtable -Depth 100
        $scriptNames = if ($json.ContainsKey('scripts')) { @($json.scripts.Keys | Sort-Object) } else { @() }
        $manifests += [ordered]@{ path = $path; sha256 = Hash-File $file; kind = 'package.json'; scriptNames = $scriptNames }
    }
    elseif ($name -match '\.(sln|slnx)$' -or $name -in @('Directory.Build.props', 'Directory.Build.targets', 'global.json', 'NuGet.Config')) {
        $manifests += [ordered]@{ path = $path; sha256 = Hash-File $file; kind = $name; scriptNames = @() }
    }
    if ($path -match '^\.github/workflows/[^/]+\.ya?ml$' -or $name -in @('.gitlab-ci.yml', 'azure-pipelines.yml')) {
        $workflows += [ordered]@{ path = $path; sha256 = Hash-File $file }
    }
    if ($name -in @('AGENTS.md', 'CLAUDE.md', 'CODEOWNERS') -or $path -match '^\.github/CODEOWNERS$') {
        $guidance += [ordered]@{ path = $path; sha256 = Hash-File $file }
    }
}
$projectPaths = @($projects | Where-Object { $_.role -eq 'source' } | ForEach-Object { $_.path })
$areaCandidates = @($projectPaths | ForEach-Object {
    $parts = $_ -split '/'
    if ($parts.Length -gt 3) { ($parts[0..2] -join '/') } elseif ($parts.Length -gt 1) { ($parts[0..($parts.Length - 2)] -join '/') } else { $parts[0] }
} | Sort-Object -Unique)
$inventory = [ordered]@{
    formatVersion = 1; scope = 'unevaluated repository files; excludes generated and transient directories'
    excludes = @($ExcludePaths | Sort-Object -Unique)
    projects = $projects; manifests = $manifests; workflows = $workflows; guidance = $guidance
    areaCandidates = $areaCandidates
}
Write-Json (Join-Path $output 'inventory.json') $inventory
$projectLines = @($projects | ForEach-Object { "| ``$($_.path)`` | $($_.role) | $(@($_.frameworks) -join ', ') | $($_.projectReferences.Count) | ``$($_.sha256)`` |" })
$manifestLines = @($manifests | ForEach-Object { "- ``$($_.path)`` ($($_.kind), SHA-256 ``$($_.sha256)``)" })
$workflowLines = @($workflows | ForEach-Object { "- ``$($_.path)`` (SHA-256 ``$($_.sha256)``)" })
$guidanceLines = @($guidance | ForEach-Object { "- ``$($_.path)`` (SHA-256 ``$($_.sha256)``)" })
Write-Lf (Join-Path $output 'INVENTORY.md') "# Target inventory`n`nEvidence is recorded in [inventory.json](inventory.json). Project references are literal XML declarations; MSBuild conditions, imports, generated files and transitive graphs are not evaluated. Source/test/fixture roles are path-name hints for review.`n`n## .NET projects ($($projects.Count))`n`n| Path | Role hint | Declared framework | Direct references | SHA-256 |`n| --- | --- | --- | ---: | --- |`n$($projectLines -join "`n")`n`n## Manifests`n`n$($manifestLines -join "`n")`n`n## CI workflows`n`n$($workflowLines -join "`n")`n`n## Agent/owner guidance`n`n$($guidanceLines -join "`n")"
$candidateLines = @($areaCandidates | ForEach-Object { "- ``$_``: confirm path boundary, layer, owner, nearby implementation and focused command." })
Write-Lf (Join-Path $output 'PROPOSAL.md') "# Guard profile review proposal`n`nThis analysis does not change active policy. No rule, owner, command, negative fixture or CI required check is inferred as authoritative. Edit [ARCHITECTURE.md](ARCHITECTURE.md) and [TECHNICAL.md](TECHNICAL.md) as target-specific drafts, then run `Invoke-V3Architecture.ps1 -Mode Review` to compare their structured blocks with repository evidence and any selected profile.`n`n## Candidate areas`n`n$($candidateLines -join "`n")`n`n## Review before enforcement`n`n1. Confirm source roots and owners against [inventory.json](inventory.json), repository guidance and maintainers.`n2. Choose real build/test commands and risk paths; compare existing architecture gate and CI authority.`n3. Specify rule JSON with explicit detector scope and a deliberate negative fixture. Keep unsupported rules advisory.`n4. Review the comparison report. Explicitly adopt to a new profile only after confirming the document baseline; then run Validate, Render/Check, Generate/Check/Test and a violating fixture before enabling a required CI check."
$draftArgs = @{ Mode = 'Draft'; TargetRoot = $root; AnalysisDirectory = $output }
if ($EvidenceDirectory) { $draftArgs.EvidenceDirectory = $EvidenceDirectory }
if ($ProfileDirectory) { $draftArgs.ProfileDirectory = $ProfileDirectory }
if ($ProfileLayoutPath) { $draftArgs.ProfileLayoutPath = $ProfileLayoutPath }
if ($ProfileRepositoryRoot) { $draftArgs.ProfileRepositoryRoot = $ProfileRepositoryRoot }
if ($ProjectId) { $draftArgs.ProjectId = $ProjectId }
if ($TargetFramework) { $draftArgs.TargetFramework = $TargetFramework }
& (Join-Path $PSScriptRoot '../scripts/Invoke-V3Architecture.ps1') @draftArgs
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw 'Architecture draft generation failed.' }
Write-Host "Analyzed $($projects.Count) .NET project(s), $($workflows.Count) workflow(s): $output"
