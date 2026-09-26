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

function Load-WorkspaceEvidence($InputObject,[string]$TargetRoot) {
    if (-not ($InputObject.PSObject.Properties.Name -contains 'workspaceEvidencePath') -or
        -not ($InputObject.PSObject.Properties.Name -contains 'workspaceEvidenceSha256')) { return $null }
    if (-not ($InputObject.PSObject.Properties.Name -contains 'workspaceEvidenceTargetCommit')) { Stop-Adapter 'invalid-input' 'Workspace evidence target commit is required.' }
    $path = [IO.Path]::GetFullPath([string]$InputObject.workspaceEvidencePath)
    $expected = [string]$InputObject.workspaceEvidenceSha256
    $expectedCommit = [string]$InputObject.workspaceEvidenceTargetCommit
    if ($expected -cnotmatch '^[a-f0-9]{64}$' -or -not [IO.File]::Exists($path) -or
        (Is-Under $path $TargetRoot) -or (Is-Under $TargetRoot ([IO.Path]::GetDirectoryName($path)))) {
        Stop-Adapter 'unsafe-path' 'Workspace evidence is missing, invalid, or overlaps TargetRoot.'
    }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expected) {
        Stop-Adapter 'integrity-failure' 'Workspace evidence hash drift.'
    }
    try { $value = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -Depth 30 }
    catch { Stop-Adapter 'integrity-failure' 'Workspace evidence is malformed.' }
    if ($expectedCommit -cnotmatch '^[a-f0-9]{40}$' -or $value.targetCommit -cne $expectedCommit -or
        $value.formatVersion -ne 1 -or $value.scope -cne 'ifx-workspace-evidence-v1' -or
        $value.pathOrder -cne 'ordinal' -or @($value.files).Count -ne $value.fileCount) {
        Stop-Adapter 'integrity-failure' 'Workspace evidence identity drift.'
    }
    return $value
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
$workspace = Load-WorkspaceEvidence $payload $targetRoot
if ($null -ne $workspace) {
    $projects = @($workspace.files | Where-Object {
        $_.extension -ceq '.csproj' -and $_.path.StartsWith('src/',[StringComparison]::Ordinal)
    } | ForEach-Object {
        $full = [IO.Path]::GetFullPath((Join-Path $targetRoot ([string]$_.path)))
        [pscustomobject]@{FullName=$full;BaseName=[IO.Path]::GetFileNameWithoutExtension($full);DirectoryName=[IO.Path]::GetDirectoryName($full);Name=[IO.Path]::GetFileName($full);CachedText=[string]$_.text}
    })
} else {
    $found = [Collections.Generic.List[object]]::new()
    $pending = [Collections.Generic.Queue[string]]::new(); $pending.Enqueue($sourceRoot)
    while ($pending.Count -gt 0) {
        $directory = $pending.Dequeue()
        foreach ($child in [IO.Directory]::EnumerateDirectories($directory)) {
            if (([IO.File]::GetAttributes($child) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { Stop-Adapter 'unsafe-path' 'Source tree contains a linked directory.' }
            if ([IO.Path]::GetFileName($child) -in @('bin','obj','node_modules','dist','coverage','.vite','guard','guards','generated')) { continue }
            $pending.Enqueue($child)
        }
        foreach ($file in [IO.Directory]::EnumerateFiles($directory,'*.csproj',[IO.SearchOption]::TopDirectoryOnly)) {
            if (([IO.File]::GetAttributes($file) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { Stop-Adapter 'unsafe-path' 'Source tree contains a linked project.' }
            $found.Add([pscustomobject]@{FullName=$file;BaseName=[IO.Path]::GetFileNameWithoutExtension($file);DirectoryName=[IO.Path]::GetDirectoryName($file);Name=[IO.Path]::GetFileName($file);CachedText=$null})
        }
    }
    $projects = @($found.ToArray() | Sort-Object FullName)
}
foreach ($project in $projects) {
    if (-not (Is-Under $project.FullName $targetRoot)) { Stop-Adapter 'unsafe-path' 'Project escapes TargetRoot.' }
    Assert-NoLink $project.FullName 'Project'
    if (-not (Matches $project.BaseName $policy.sourceProjectPattern)) { continue }
    $matched++
    try {
        $settings = [Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
        $settings.XmlResolver = $null
        $textReader = if ($null -ne $project.CachedText) { [IO.StringReader]::new([string]$project.CachedText) } else { $null }
        $reader = if ($null -ne $textReader) { [Xml.XmlReader]::Create($textReader, $settings) } else { [Xml.XmlReader]::Create($project.FullName, $settings) }
        try {
            $document = [xml]::new()
            $document.Load($reader)
        } finally { $reader.Dispose(); if ($null -ne $textReader) { $textReader.Dispose() } }
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
