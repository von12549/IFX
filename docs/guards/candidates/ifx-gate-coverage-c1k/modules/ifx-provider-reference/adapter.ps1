Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$claimId = 'IFX.C1.PROVIDER_CONTRACT_RAW'
$ruleId = 'PROVIDER-CONTRACT'
$detectorId = 'ifx-provider-reference'
$matched = 0
$findings = [Collections.Generic.List[object]]::new()

function Emit([string] $Status, [string] $Category, [string] $Message = '') {
    $result = [ordered]@{
        formatVersion = 1; status = $Status; exitCategory = $Category
        findings = @($findings.ToArray())
        coverage = @([ordered]@{ claimId = $claimId; matched = $matched; minimum = 1 })
    }
    if ($Message) { $result.message = $Message }
    [Console]::Out.WriteLine(($result | ConvertTo-Json -Depth 12 -Compress))
}
function Stop-Adapter([string] $Category, [string] $Message) {
    Emit 'error' $Category $Message
    exit 0
}
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    return $relative -ne '..' -and -not [IO.Path]::IsPathRooted($relative) -and
        -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal)
}
function Assert-NoLink([string] $Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ([IO.File]::Exists($current) -or [IO.Directory]::Exists($current)) {
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) {
            Stop-Adapter 'unsafe-path' 'Project path or ancestor is linked.'
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if (-not $parent -or $parent -ceq $current) { break }
        $current = $parent
    }
}
function Matches([string] $Name, [string] $Pattern) {
    $expression = '^' + [regex]::Escape($Pattern).Replace('\*', '.*') + '$'
    [regex]::IsMatch($Name, $expression, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
}
function Get-Ring([string] $Name) {
    foreach ($entry in $policy.rings.PSObject.Properties) {
        if (@($entry.Value | Where-Object { Matches $Name ([string]$_) }).Count -gt 0) { return $entry.Name }
    }
    return 'Outside'
}
function Get-Module([string] $Name, [string] $Path, [string] $Ring) {
    foreach ($pattern in $policy.ownership.modulePatterns) {
        $expression = '^' + [regex]::Escape([string]$pattern).Replace('\{module\}', '(?<module>[^.]+)').Replace('\*', '.*') + '$'
        $match = [regex]::Match($Name, $expression, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success) { return $match.Groups['module'].Value }
    }
    if ($Ring -in @('RuntimeHost','Test')) { return $null }
    $projectDir = [IO.Path]::GetDirectoryName($Path)
    $parent = [IO.Path]::GetDirectoryName($projectDir)
    if (-not $parent) { return $null }
    $fallback = [IO.Path]::GetFileName($parent)
    if ($fallback) { return $fallback }
    return $null
}
function Read-Project([string] $Path) {
    Assert-NoLink $Path
    try {
        $settings = [Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
        $settings.XmlResolver = $null
        $reader = [Xml.XmlReader]::Create($Path, $settings)
        try {
            $xml = [xml]::new()
            $xml.Load($reader)
            if ($xml.DocumentElement.LocalName -cne 'Project') { throw 'Root is not Project.' }
        }
        finally { $reader.Dispose() }
    }
    catch { Stop-Adapter 'invalid-input' "Project XML is invalid: $([IO.Path]::GetFileName($Path))." }
    $name = [IO.Path]::GetFileNameWithoutExtension($Path)
    $ring = Get-Ring $name
    return [pscustomobject]@{ path = $Path; name = $name; ring = $ring; module = Get-Module $name $Path $ring; xml = $xml }
}

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) { Stop-Adapter 'invalid-input' 'V4_STAGE_INPUT_JSON is required.' }
try { $inputObject = $env:V4_STAGE_INPUT_JSON | ConvertFrom-Json -Depth 30 }
catch { Stop-Adapter 'invalid-input' 'Stage input is not valid JSON.' }
if ($inputObject.formatVersion -ne 1 -or $inputObject.stage -cne 'pre' -or
    @($inputObject.config.enabledClaims).Count -ne 1 -or $inputObject.config.enabledClaims[0] -cne $claimId -or
    @($inputObject.relativeRoots) -notcontains 'src') { Stop-Adapter 'invalid-input' 'Stage or claim selection is invalid.' }
$targetRoot = [IO.Path]::GetFullPath([string]$inputObject.targetRoot)
if (-not [IO.Path]::IsPathFullyQualified([string]$inputObject.targetRoot) -or -not [IO.Directory]::Exists($targetRoot)) {
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
if ($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-provider-reference-c1k' -or
    $policy.scanRoot -cne 'src' -or $policy.claimId -cne $claimId -or
    $policy.ruleId -cne $ruleId -or $policy.minimumAdapterProjects -ne 1) {
    Stop-Adapter 'integrity-failure' 'Candidate policy identity drift.'
}
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $targetRoot 'src'))
if (-not (Is-Under $sourceRoot $targetRoot)) { Stop-Adapter 'unsafe-path' 'Source root escapes TargetRoot.' }
if (-not [IO.Directory]::Exists($sourceRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot/src is missing.' }
Assert-NoLink $sourceRoot
$stack = [Collections.Generic.Stack[string]]::new()
$stack.Push($sourceRoot)
$paths = [Collections.Generic.List[string]]::new()
while ($stack.Count -gt 0) {
    $dir = $stack.Pop()
    foreach ($item in @(Get-ChildItem -LiteralPath $dir -Force | Sort-Object Name)) {
        if ($item.PSIsContainer) {
            if ($item.Name -in @('guard','guards','generated','obj','bin','.git')) { continue }
            if (-not (Is-Under $item.FullName $targetRoot)) { Stop-Adapter 'unsafe-path' 'Source directory escapes TargetRoot.' }
            Assert-NoLink $item.FullName
            $stack.Push($item.FullName)
        }
        elseif ($item.Name.EndsWith('.csproj', [StringComparison]::OrdinalIgnoreCase)) {
            if (-not (Is-Under $item.FullName $targetRoot)) { Stop-Adapter 'unsafe-path' 'Project escapes TargetRoot.' }
            $paths.Add($item.FullName)
        }
    }
}
$projects = @($paths.ToArray() | Sort-Object | ForEach-Object { Read-Project $_ })
foreach ($project in $projects) {
    if ($project.ring -cne 'IntegrationAdapter') { continue }
    $matched++
    foreach ($reference in @($project.xml.SelectNodes("//*[local-name()='ProjectReference']"))) {
        $include = [string]$reference.GetAttribute('Include')
        if (-not $include) { continue }
        if ([IO.Path]::IsPathRooted($include) -or $include -match '^[A-Za-z]:') { Stop-Adapter 'unsafe-path' 'Absolute ProjectReference is forbidden.' }
        $targetPath = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetDirectoryName($project.path)) ($include.Replace('\', [IO.Path]::DirectorySeparatorChar).Replace('/', [IO.Path]::DirectorySeparatorChar))))
        $targetRelative = [IO.Path]::GetRelativePath($targetRoot, $targetPath).Replace('\','/')
        if (-not (Is-Under $targetPath $targetRoot) -or $targetRelative -match '(^|/)(guard|guards)(/|$)') {
            Stop-Adapter 'unsafe-path' 'ProjectReference escapes the allowed TargetRoot scope.'
        }
        if (-not [IO.File]::Exists($targetPath)) { Stop-Adapter 'prerequisite-missing' 'ProjectReference target is missing.' }
        $target = Read-Project $targetPath
        if ($target.ring -cne 'Contracts' -or -not $target.module -or -not $project.module -or
            $target.module -ieq $project.module) { continue }
        $providers = @($policy.providerContracts.PSObject.Properties | Where-Object Name -IEQ $project.module | ForEach-Object Value)
        if (@($providers | ForEach-Object { @($_) }) -icontains $target.module) { continue }
        $from = [IO.Path]::GetRelativePath($targetRoot, $project.path).Replace('\','/')
        $to = [IO.Path]::GetRelativePath($targetRoot, $targetPath).Replace('\','/')
        $findings.Add([ordered]@{ ruleId = $ruleId; subject = "$from -> $to"; evidenceKind = 'project-reference-raw'; detectorId = $detectorId; severity = 'blocking' })
    }
}
if ($matched -eq 0) {
    $findings.Add([ordered]@{ ruleId = $ruleId; subject = 'src: zero IntegrationAdapter projects'; evidenceKind = 'coverage'; detectorId = $detectorId; severity = 'blocking' })
}
$sorted = $findings.ToArray()
[Array]::Sort($sorted, [Comparison[object]]{ param($a,$b) [StringComparer]::Ordinal.Compare([string]$a['subject'], [string]$b['subject']) })
$findings.Clear()
foreach ($finding in $sorted) { $findings.Add($finding) }
Emit $(if ($findings.Count -eq 0) { 'pass' } else { 'fail' }) $(if ($findings.Count -eq 0) { 'success' } else { 'findings-blocking' })
