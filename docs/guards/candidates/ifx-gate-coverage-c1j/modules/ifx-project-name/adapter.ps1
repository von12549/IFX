Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$claimId = 'IFX.C1.PROJECT_NAME_FORBIDDEN'
$ruleId = 'PROJECT-NAME-FORBIDDEN'
$detectorId = 'ifx-project-name'
$matched = 0
$findings = [Collections.Generic.List[object]]::new()

function Emit([string] $Status, [string] $Category, [string] $Message = '') {
    $result = [ordered]@{
        formatVersion = 1
        status = $Status
        exitCategory = $Category
        findings = @($findings.ToArray())
        coverage = @([ordered]@{ claimId = $claimId; matched = $matched; minimum = 1 })
    }
    if ($Message) { $result.message = $Message }
    $result | ConvertTo-Json -Depth 12 -Compress
}
function Stop-Adapter([string] $Category, [string] $Message) {
    Emit 'error' $Category $Message
    exit 0
}
function Assert-NoLink([string] $Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ([IO.File]::Exists($current) -or [IO.Directory]::Exists($current)) {
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) {
            Stop-Adapter 'unsafe-path' 'Subject or ancestor is a linked path.'
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if (-not $parent -or $parent -ceq $current) { break }
        $current = $parent
    }
}
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    return $relative -ne '..' -and -not [IO.Path]::IsPathRooted($relative) -and
        -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal)
}
function Matches([string] $Name, [string] $Pattern) {
    $expression = '^' + [regex]::Escape($Pattern).Replace('\*', '.*') + '$'
    return [regex]::IsMatch($Name, $expression, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) {
    Stop-Adapter 'invalid-input' 'V4_STAGE_INPUT_JSON is required.'
}
try { $inputObject = $env:V4_STAGE_INPUT_JSON | ConvertFrom-Json -Depth 30 }
catch { Stop-Adapter 'invalid-input' 'Stage input is not valid JSON.' }
if ($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'pre' -or
    @($inputObject.config.enabledClaims).Count -ne 1 -or
    $inputObject.config.enabledClaims[0] -cne $claimId -or
    @($inputObject.relativeRoots) -notcontains 'src') {
    Stop-Adapter 'invalid-input' 'Stage or claim selection is invalid.'
}
$targetRoot = [IO.Path]::GetFullPath([string]$inputObject.targetRoot)
if (-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot) -or
    -not [IO.Directory]::Exists($targetRoot)) {
    Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing or not absolute.'
}
Assert-NoLink $targetRoot
$policyPath = Join-Path $PSScriptRoot 'policy.json'
if (-not [IO.File]::Exists($policyPath)) { Stop-Adapter 'integrity-failure' 'Candidate policy is missing.' }
if ((Get-FileHash -LiteralPath $policyPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$inputObject.config.policySha256) {
    Stop-Adapter 'integrity-failure' 'Candidate policy hash drift.'
}
try { $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -Depth 30 }
catch { Stop-Adapter 'integrity-failure' 'Candidate policy is malformed.' }
if ($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-project-name-c1j' -or
    $policy.scanRoot -cne 'src' -or $policy.claimId -cne $claimId -or
    $policy.ruleId -cne $ruleId -or $policy.minimumInScopeProjects -ne 1 -or
    $policy.sourceSeverity -cne 'drift') {
    Stop-Adapter 'integrity-failure' 'Candidate policy identity drift.'
}
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $targetRoot 'src'))
if (-not (Is-Under $sourceRoot $targetRoot)) { Stop-Adapter 'unsafe-path' 'Source root escapes TargetRoot.' }
if (-not [IO.Directory]::Exists($sourceRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot/src is missing.' }
Assert-NoLink $sourceRoot

$stack = [Collections.Generic.Stack[string]]::new()
$stack.Push($sourceRoot)
while ($stack.Count -gt 0) {
    $directory = $stack.Pop()
    foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force | Sort-Object Name)) {
        if ($item.PSIsContainer) {
            if ($item.Name -in @('guard', 'guards', 'generated', 'obj', 'bin', '.git')) { continue }
            if (-not (Is-Under $item.FullName $targetRoot)) { Stop-Adapter 'unsafe-path' 'Source directory escapes TargetRoot.' }
            Assert-NoLink $item.FullName
            $stack.Push($item.FullName)
            continue
        }
        if (-not $item.Name.EndsWith('.csproj', [StringComparison]::OrdinalIgnoreCase)) { continue }
        if (-not (Is-Under $item.FullName $targetRoot)) { Stop-Adapter 'unsafe-path' 'Project escapes TargetRoot.' }
        Assert-NoLink $item.FullName
        try {
            $settings = [Xml.XmlReaderSettings]::new()
            $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
            $settings.XmlResolver = $null
            $reader = [Xml.XmlReader]::Create($item.FullName, $settings)
            try {
                $document = [xml]::new()
                $document.Load($reader)
                if ($document.DocumentElement.LocalName -cne 'Project') { throw 'Root is not Project.' }
            }
            finally { $reader.Dispose() }
        }
        catch { Stop-Adapter 'invalid-input' "Project XML is invalid: $($item.Name)." }
        $ring = 'Outside'
        foreach ($entry in $policy.rings.PSObject.Properties) {
            if (@($entry.Value | Where-Object { Matches $item.BaseName ([string]$_) }).Count -gt 0) {
                $ring = $entry.Name
                break
            }
        }
        if ($ring -ceq 'Outside') { continue }
        $matched++
        if (@($policy.forbiddenProjectNames | Where-Object { Matches $item.BaseName ([string]$_) }).Count -eq 0) { continue }
        $findings.Add([ordered]@{
            ruleId = $ruleId
            subject = [IO.Path]::GetRelativePath($targetRoot, $item.FullName).Replace('\', '/')
            evidenceKind = 'project-declaration'
            detectorId = $detectorId
            severity = 'blocking'
        })
    }
}
if ($matched -eq 0) {
    $findings.Add([ordered]@{
        ruleId = $ruleId
        subject = 'src: zero in-scope projects'
        evidenceKind = 'coverage'
        detectorId = $detectorId
        severity = 'blocking'
    })
}
$ordered = $findings.ToArray()
[Array]::Sort($ordered, [Comparison[object]]{
    param($a, $b)
    [StringComparer]::Ordinal.Compare([string]$a['subject'], [string]$b['subject'])
})
$findings.Clear()
foreach ($finding in $ordered) { $findings.Add($finding) }
Emit $(if ($findings.Count -eq 0) { 'pass' } else { 'fail' }) `
    $(if ($findings.Count -eq 0) { 'success' } else { 'findings-blocking' })
