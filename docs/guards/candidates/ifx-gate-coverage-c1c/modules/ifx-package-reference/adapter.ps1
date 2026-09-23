Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$detectorId = 'ifx-package-reference'
$allowClaim = 'IFX.C1.PACKAGE_ALLOW_RAW'
$denyClaim = 'IFX.C1.PACKAGE_DENY_RAW'
$allowMatched = 0
$denyMatched = 0
$findings = [Collections.Generic.List[object]]::new()

function Write-Result([string] $Status, [string] $Category, [string] $Message = '') {
    $result = [ordered]@{
        formatVersion = 1
        status = $Status
        exitCategory = $Category
        findings = @($findings.ToArray())
        coverage = @(
            [ordered]@{ claimId = $allowClaim; matched = $allowMatched; minimum = 1 }
            [ordered]@{ claimId = $denyClaim; matched = $denyMatched; minimum = 1 }
        )
    }
    if ($Message) { $result.message = $Message }
    $result | ConvertTo-Json -Depth 20 -Compress
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

function Assert-NoLink([string] $Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ([IO.File]::Exists($current) -or [IO.Directory]::Exists($current)) {
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) {
            Stop-Adapter 'unsafe-path' 'Source path crosses a link.'
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

function Matches-Any([string] $Name, $Patterns) {
    foreach ($pattern in $Patterns) {
        if (Matches $Name ([string]$pattern)) { return $true }
    }
    return $false
}

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) {
    Stop-Adapter 'invalid-input' 'V4_STAGE_INPUT_JSON is required.'
}
try { $payload = $env:V4_STAGE_INPUT_JSON | ConvertFrom-Json -Depth 30 }
catch { Stop-Adapter 'invalid-input' 'Stage input is not valid JSON.' }
if ($payload.formatVersion -ne 1 -or $payload.stage -cne 'pre' -or
    @($payload.config.enabledClaims).Count -ne 2 -or
    @($payload.config.enabledClaims) -notcontains $allowClaim -or
    @($payload.config.enabledClaims) -notcontains $denyClaim) {
    Stop-Adapter 'invalid-input' 'Stage or enabled claims are invalid.'
}
if (-not [IO.Path]::IsPathFullyQualified([string]$payload.targetRoot)) {
    Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.'
}
try { $targetRoot = [IO.Path]::GetFullPath([string]$payload.targetRoot) }
catch { Stop-Adapter 'invalid-input' 'TargetRoot is invalid.' }
if (-not [IO.Directory]::Exists($targetRoot)) {
    Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing.'
}
Assert-NoLink $targetRoot

$policyPath = Join-Path $PSScriptRoot 'policy.json'
if (-not [IO.File]::Exists($policyPath)) { Stop-Adapter 'integrity-failure' 'Candidate policy is missing.' }
$policyHash = (Get-FileHash -LiteralPath $policyPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($policyHash -cne [string]$payload.config.policySha256) {
    Stop-Adapter 'integrity-failure' 'Candidate policy hash differs from Profile configuration.'
}
try { $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -Depth 30 }
catch { Stop-Adapter 'integrity-failure' 'Candidate policy is invalid.' }
if ($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-package-reference-c1c' -or
    $policy.scanRoot -cne 'src' -or $policy.minimumProjectsPerRing -ne 1 -or
    @($policy.claimIds) -join ',' -cne "$allowClaim,$denyClaim") {
    Stop-Adapter 'integrity-failure' 'Candidate policy identity is invalid.'
}
if (@($payload.relativeRoots) -notcontains 'src') {
    Stop-Adapter 'invalid-input' 'Profile scan roots must include src.'
}
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $targetRoot 'src'))
if (-not (Is-Under $sourceRoot $targetRoot)) { Stop-Adapter 'unsafe-path' 'Source root escapes TargetRoot.' }
if (-not [IO.Directory]::Exists($sourceRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot/src is missing.' }
Assert-NoLink $sourceRoot

$ringNames = @('Domain', 'Contracts', 'Application', 'Presentation')
$ringCounts = [ordered]@{ Domain = 0; Contracts = 0; Application = 0; Presentation = 0 }
$items = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -Force)
foreach ($item in $items) { Assert-NoLink $item.FullName }
$projects = @($items | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.csproj' } | Sort-Object FullName)

foreach ($project in $projects) {
    if (-not (Is-Under $project.FullName $sourceRoot)) { Stop-Adapter 'unsafe-path' 'Project escapes source root.' }
    $matchedRings = @($ringNames | Where-Object { Matches-Any $project.BaseName $policy.rings.$_ })
    if ($matchedRings.Count -gt 1) { Stop-Adapter 'integrity-failure' 'Project matches multiple policy rings.' }
    if ($matchedRings.Count -eq 0) { continue }
    $ring = [string]$matchedRings[0]
    $ringCounts[$ring]++
    if ($ring -in @('Domain', 'Contracts', 'Application')) { $allowMatched++ }
    if ($ring -in @('Contracts', 'Presentation')) { $denyMatched++ }

    try {
        $settings = [Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
        $settings.XmlResolver = $null
        $reader = [Xml.XmlReader]::Create($project.FullName, $settings)
        try {
            $document = [xml]::new()
            $document.Load($reader)
        } finally { $reader.Dispose() }
    } catch { Stop-Adapter 'invalid-input' "Project XML is invalid: $($project.Name)." }

    foreach ($reference in @($document.SelectNodes("//*[local-name()='PackageReference']"))) {
        $id = [string]$reference.GetAttribute('Include')
        if (-not $id) { continue }
        $denied = if ($ring -in @('Contracts', 'Presentation')) {
            Matches-Any $id $policy.forbiddenPackages.$ring
        } else { $false }
        $allowed = if ($ring -in @('Domain', 'Contracts', 'Application')) {
            Matches-Any $id $policy.allowedPackages.$ring
        } else { $true }
        if (-not $denied -and $allowed) { continue }
        $rule = if ($denied) { 'RING-PACKAGE-FORBIDDEN' } else { 'RING-PACKAGE' }
        $relative = [IO.Path]::GetRelativePath($targetRoot, $project.FullName).Replace('\', '/')
        $findings.Add([ordered]@{
            ruleId = $rule
            subject = "$relative -> $id"
            evidenceKind = 'project-model-raw'
            detectorId = $detectorId
            severity = 'blocking'
        })
    }
}

foreach ($ring in $ringNames) {
    if ($ringCounts[$ring] -ne 0) { continue }
    $findings.Add([ordered]@{
        ruleId = 'RING-PACKAGE'
        subject = "src: zero $ring projects"
        evidenceKind = 'coverage'
        detectorId = $detectorId
        severity = 'blocking'
    })
}
$sorted = $findings.ToArray()
[Array]::Sort($sorted, [Comparison[object]]{
    param($left, $right)
    $subject = [StringComparer]::Ordinal.Compare([string]$left['subject'], [string]$right['subject'])
    if ($subject -ne 0) { return $subject }
    return [StringComparer]::Ordinal.Compare([string]$left['ruleId'], [string]$right['ruleId'])
})
$findings.Clear()
foreach ($finding in $sorted) { $findings.Add($finding) }
Write-Result $(if ($findings.Count -eq 0) { 'pass' } else { 'fail' }) `
    $(if ($findings.Count -eq 0) { 'success' } else { 'findings-blocking' })
