Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$claimId = 'IFX.L2.2.DIRECT_DOMAIN_CONTRACTS'
$ruleId = 'RING-DIRECTION'
$detectorId = 'ifx-domain-reference'
$matched = 0
$findings = [Collections.Generic.List[object]]::new()

function Write-Result([string] $Status, [string] $Category, [string] $Message = '') {
    $document = [ordered]@{
        formatVersion = 1
        status = $Status
        exitCategory = $Category
        findings = @($findings.ToArray())
        coverage = @([ordered]@{ claimId = $claimId; matched = $matched; minimum = 1 })
    }
    if ($Message) { $document.message = $Message }
    $document | ConvertTo-Json -Depth 16 -Compress
}

function Stop-Adapter([string] $Category, [string] $Message) {
    Write-Result 'error' $Category $Message
    exit 0
}

function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    return $relative -ne '..' -and -not [IO.Path]::IsPathRooted($relative) -and
        -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal)
}

function Assert-NoLink([string] $Path, [string] $Label) {
    $current = [IO.Path]::GetFullPath($Path)
    while ([IO.File]::Exists($current) -or [IO.Directory]::Exists($current)) {
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) {
            Stop-Adapter 'unsafe-path' "$Label crosses a link."
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if (-not $parent -or $parent -ceq $current) { break }
        $current = $parent
    }
}

function Matches([string] $Name, [string] $Pattern) {
    $matcher = [Management.Automation.WildcardPattern]::new($Pattern, [Management.Automation.WildcardOptions]::IgnoreCase)
    return $matcher.IsMatch($Name)
}

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) {
    Stop-Adapter 'invalid-input' 'V4_STAGE_INPUT_JSON is required.'
}
try { $payload = $env:V4_STAGE_INPUT_JSON | ConvertFrom-Json -Depth 30 }
catch { Stop-Adapter 'invalid-input' 'Stage input is not valid JSON.' }
if ($payload.formatVersion -ne 1 -or $payload.stage -cne 'pre' -or
    $payload.config.enabledClaims.Count -ne 1 -or
    $payload.config.enabledClaims[0] -cne $claimId) {
    Stop-Adapter 'invalid-input' 'Stage or enabled claim is invalid.'
}

$targetRoot = [IO.Path]::GetFullPath([string]$payload.targetRoot)
if (-not [IO.Path]::IsPathFullyQualified([string]$payload.targetRoot) -or
    -not [IO.Directory]::Exists($targetRoot)) {
    Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing or not absolute.'
}
Assert-NoLink $targetRoot 'TargetRoot'
$policyPath = Join-Path $PSScriptRoot 'policy.json'
if (-not [IO.File]::Exists($policyPath)) { Stop-Adapter 'integrity-failure' 'Candidate policy is missing.' }
$actualPolicyHash = (Get-FileHash -LiteralPath $policyPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualPolicyHash -cne [string]$payload.config.policySha256) {
    Stop-Adapter 'integrity-failure' 'Candidate policy hash differs from Profile configuration.'
}
$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -Depth 15
if ($policy.formatVersion -ne 1 -or $policy.claimId -cne $claimId -or $policy.ruleId -cne $ruleId -or
    $policy.scanRoot -cne 'src' -or $policy.minimumDomainProjects -ne 1) {
    Stop-Adapter 'integrity-failure' 'Candidate policy identity is invalid.'
}
if (@($payload.relativeRoots) -notcontains 'src') {
    Stop-Adapter 'invalid-input' 'Profile scan roots must include src.'
}
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $targetRoot $policy.scanRoot))
if (-not (Is-Under $sourceRoot $targetRoot)) { Stop-Adapter 'unsafe-path' 'Source root escapes TargetRoot.' }
if (-not [IO.Directory]::Exists($sourceRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot/src is missing.' }
Assert-NoLink $sourceRoot 'Source root'
foreach ($directory in @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -Directory -Force)) {
    Assert-NoLink $directory.FullName 'Source directory'
}

$projects = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Filter '*.csproj' -Force |
    Sort-Object -Property FullName)
foreach ($project in $projects) {
    if (-not (Is-Under $project.FullName $targetRoot)) { Stop-Adapter 'unsafe-path' 'Project escapes TargetRoot.' }
    Assert-NoLink $project.FullName 'Project'
    if (-not (Matches $project.BaseName $policy.sourceProjectPattern)) { continue }
    $matched++
    try {
        $settings = [Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
        $settings.XmlResolver = $null
        $reader = [Xml.XmlReader]::Create($project.FullName, $settings)
        try {
            $document = [xml]::new()
            $document.Load($reader)
        } finally { $reader.Dispose() }
    } catch { Stop-Adapter 'invalid-input' "Domain project XML is invalid: $($project.Name)." }
    $references = @($document.SelectNodes("//*[local-name()='ProjectReference']"))
    foreach ($reference in $references) {
        $include = [string]$reference.GetAttribute('Include')
        if (-not $include) { continue }
        if ([IO.Path]::IsPathRooted($include) -or $include -match '^[A-Za-z]:') {
            Stop-Adapter 'unsafe-path' 'Absolute ProjectReference is not allowed.'
        }
        $referencePath = [IO.Path]::GetFullPath((Join-Path $project.DirectoryName ($include.Replace('\', [IO.Path]::DirectorySeparatorChar).Replace('/', [IO.Path]::DirectorySeparatorChar))))
        if (-not (Is-Under $referencePath $targetRoot)) { Stop-Adapter 'unsafe-path' 'ProjectReference escapes TargetRoot.' }
        if (-not [IO.File]::Exists($referencePath)) { Stop-Adapter 'prerequisite-missing' 'ProjectReference target is missing.' }
        Assert-NoLink $referencePath 'ProjectReference target'
        $targetName = [IO.Path]::GetFileNameWithoutExtension($referencePath)
        if (@($policy.targetProjectPatterns | Where-Object { Matches $targetName ([string]$_) }).Count -eq 0) { continue }
        $sourceRelative = [IO.Path]::GetRelativePath($targetRoot, $project.FullName).Replace('\', '/')
        $targetRelative = [IO.Path]::GetRelativePath($targetRoot, $referencePath).Replace('\', '/')
        $findings.Add([ordered]@{
            ruleId = $ruleId
            subject = "$sourceRelative -> $targetRelative"
            evidenceKind = 'project-model-raw'
            detectorId = $detectorId
            severity = 'blocking'
        })
    }
}
if ($matched -eq 0) {
    $findings.Add([ordered]@{
        ruleId = $ruleId
        subject = 'src: zero Domain projects'
        evidenceKind = 'coverage'
        detectorId = $detectorId
        severity = 'blocking'
    })
}
$sorted = $findings.ToArray()
[Array]::Sort($sorted, [Comparison[object]]{
    param($left, $right)
    [StringComparer]::Ordinal.Compare([string]$left['subject'], [string]$right['subject'])
})
$findings.Clear()
foreach ($finding in $sorted) { $findings.Add($finding) }
Write-Result $(if ($findings.Count -eq 0) { 'pass' } else { 'fail' }) `
    $(if ($findings.Count -eq 0) { 'success' } else { 'findings-blocking' })
