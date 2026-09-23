Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$claimId = 'IFX.C1.RING_GRAPH_RAW'
$ruleId = 'RING-DIRECTION'
$detectorId = 'ifx-ring-graph'
$matched = 0
$domainMatched = 0
$findings = [Collections.Generic.List[object]]::new()

function Write-Result([string] $Status, [string] $Category, [string] $Message = '') {
    $result = [ordered]@{
        formatVersion = 1
        status = $Status
        exitCategory = $Category
        findings = @($findings.ToArray())
        coverage = @([ordered]@{ claimId = $claimId; matched = $matched; minimum = 1 })
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
            Stop-Adapter 'unsafe-path' 'Project graph crosses a link.'
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

function Ring-Of([string] $Name) {
    $found = [Collections.Generic.List[string]]::new()
    foreach ($ring in $policy.rings.PSObject.Properties.Name) {
        foreach ($pattern in $policy.rings.PSObject.Properties[$ring].Value) {
            if (Matches $Name ([string]$pattern)) { $found.Add($ring); break }
        }
    }
    if ($found.Count -gt 1) { Stop-Adapter 'integrity-failure' "Project matches multiple policy rings: $Name." }
    if ($found.Count -eq 0) { return 'Outside' }
    return $found[0]
}

function Stops-Flow($Reference) {
    $value = [string]$Reference.GetAttribute('PrivateAssets')
    if (-not $value) {
        $child = $Reference.SelectSingleNode("./*[local-name()='PrivateAssets']")
        if ($null -ne $child) { $value = [string]$child.InnerText }
    }
    return @($value -split '[;,]' | ForEach-Object Trim | Where-Object { $_ -ieq 'all' -or $_ -ieq 'compile' }).Count -gt 0
}

function Read-Project([string] $Path) {
    if (-not [IO.File]::Exists($Path)) { Stop-Adapter 'prerequisite-missing' 'ProjectReference target is missing.' }
    Assert-NoLink $Path
    try {
        $settings = [Xml.XmlReaderSettings]::new()
        $settings.DtdProcessing = [Xml.DtdProcessing]::Prohibit
        $settings.XmlResolver = $null
        $reader = [Xml.XmlReader]::Create($Path, $settings)
        try {
            $document = [xml]::new()
            $document.Load($reader)
        } finally { $reader.Dispose() }
    } catch { Stop-Adapter 'invalid-input' "Project XML is invalid: $([IO.Path]::GetFileName($Path))." }
    $refs = [Collections.Generic.List[object]]::new()
    foreach ($reference in @($document.SelectNodes("//*[local-name()='ProjectReference']"))) {
        $include = [string]$reference.GetAttribute('Include')
        if (-not $include) { continue }
        if ([IO.Path]::IsPathRooted($include) -or $include -match '^[A-Za-z]:') {
            Stop-Adapter 'unsafe-path' 'Absolute ProjectReference is not allowed.'
        }
        try {
            $normalized = $include.Replace('\', [IO.Path]::DirectorySeparatorChar).Replace('/', [IO.Path]::DirectorySeparatorChar)
            $target = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetDirectoryName($Path)) $normalized))
        } catch { Stop-Adapter 'invalid-input' 'ProjectReference path is invalid.' }
        if (-not (Is-Under $target $targetRoot)) { Stop-Adapter 'unsafe-path' 'ProjectReference escapes TargetRoot.' }
        $relative = [IO.Path]::GetRelativePath($targetRoot, $target).Replace('\', '/')
        if ($relative -match '(^|/)(guard|guards)(/|$)') { Stop-Adapter 'unsafe-path' 'ProjectReference enters guard source.' }
        if ([IO.Path]::GetExtension($target) -ine '.csproj') { Stop-Adapter 'invalid-input' 'ProjectReference must target a csproj.' }
        if (-not [IO.File]::Exists($target)) { Stop-Adapter 'prerequisite-missing' 'ProjectReference target is missing.' }
        Assert-NoLink $target
        $refs.Add([pscustomobject]@{ path = $target; stops = (Stops-Flow $reference) })
    }
    $disabled = $document.SelectSingleNode("//*[local-name()='PropertyGroup']/*[local-name()='DisableTransitiveProjectReferences']")
    return [pscustomobject]@{
        path = $Path
        name = [IO.Path]::GetFileNameWithoutExtension($Path)
        ring = Ring-Of ([IO.Path]::GetFileNameWithoutExtension($Path))
        disabled = ($null -ne $disabled -and [string]$disabled.InnerText -ieq 'true')
        refs = @($refs.ToArray())
    }
}

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) {
    Stop-Adapter 'invalid-input' 'V4_STAGE_INPUT_JSON is required.'
}
try { $payload = $env:V4_STAGE_INPUT_JSON | ConvertFrom-Json -Depth 30 }
catch { Stop-Adapter 'invalid-input' 'Stage input is not valid JSON.' }
if ($payload.formatVersion -ne 1 -or $payload.stage -cne 'pre' -or
    @($payload.config.enabledClaims).Count -ne 1 -or
    $payload.config.enabledClaims[0] -cne $claimId) {
    Stop-Adapter 'invalid-input' 'Stage or enabled claim is invalid.'
}
if (-not [IO.Path]::IsPathFullyQualified([string]$payload.targetRoot)) {
    Stop-Adapter 'prerequisite-missing' 'TargetRoot must be absolute.'
}
try { $targetRoot = [IO.Path]::GetFullPath([string]$payload.targetRoot) }
catch { Stop-Adapter 'invalid-input' 'TargetRoot is invalid.' }
if (-not [IO.Directory]::Exists($targetRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot is missing.' }
Assert-NoLink $targetRoot
$policyPath = Join-Path $PSScriptRoot 'policy.json'
if (-not [IO.File]::Exists($policyPath)) { Stop-Adapter 'integrity-failure' 'Candidate policy is missing.' }
$policyHash = (Get-FileHash -LiteralPath $policyPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($policyHash -cne [string]$payload.config.policySha256) {
    Stop-Adapter 'integrity-failure' 'Candidate policy hash differs from Profile configuration.'
}
try { $policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -Depth 30 }
catch { Stop-Adapter 'integrity-failure' 'Candidate policy is invalid.' }
if ($policy.formatVersion -ne 1 -or $policy.id -cne 'ifx-ring-graph-c1d' -or
    $policy.scanRoot -cne 'src' -or $policy.claimId -cne $claimId -or
    $policy.minimumDomainProjects -ne 1) {
    Stop-Adapter 'integrity-failure' 'Candidate policy identity is invalid.'
}
if (@($payload.relativeRoots) -notcontains 'src') { Stop-Adapter 'invalid-input' 'Profile scan roots must include src.' }
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $targetRoot 'src'))
if (-not (Is-Under $sourceRoot $targetRoot)) { Stop-Adapter 'unsafe-path' 'Source root escapes TargetRoot.' }
if (-not [IO.Directory]::Exists($sourceRoot)) { Stop-Adapter 'prerequisite-missing' 'TargetRoot/src is missing.' }
Assert-NoLink $sourceRoot
$items = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -Force)
foreach ($item in $items) { Assert-NoLink $item.FullName }
$entries = @($items | Where-Object { -not $_.PSIsContainer -and $_.Extension -ieq '.csproj' } | Sort-Object FullName | ForEach-Object FullName)

$nodes = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
$pending = [Collections.Generic.Queue[string]]::new()
foreach ($entry in $entries) { $pending.Enqueue($entry) }
while ($pending.Count -gt 0) {
    $path = $pending.Dequeue()
    if ($nodes.ContainsKey($path)) { continue }
    $node = Read-Project $path
    $nodes.Add($path, $node)
    foreach ($reference in $node.refs) { $pending.Enqueue($reference.path) }
}

foreach ($entry in $entries) {
    $root = $nodes[$entry]
    if ($root.ring -ceq 'Outside') { continue }
    $matched++
    if ($root.ring -ceq 'Domain') { $domainMatched++ }
    $reached = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
    $frontier = [Collections.Generic.Queue[object]]::new()
    foreach ($reference in $root.refs) {
        if ($reached.ContainsKey($reference.path)) { continue }
        $chain = @([pscustomobject]@{ from = $root.path; to = $reference.path; stops = $reference.stops })
        $reached.Add($reference.path, $chain)
        $frontier.Enqueue([pscustomobject]@{ path = $reference.path; chain = $chain })
    }
    if (-not $root.disabled) {
        while ($frontier.Count -gt 0) {
            $current = $frontier.Dequeue()
            if (-not $nodes.ContainsKey($current.path)) { continue }
            $currentNode = $nodes[$current.path]
            if (@($policy.transitiveBoundaryRoles) -contains $currentNode.ring) { continue }
            foreach ($reference in $currentNode.refs) {
                if ($reference.stops -or $reached.ContainsKey($reference.path) -or
                    [StringComparer]::OrdinalIgnoreCase.Equals($reference.path, $root.path)) { continue }
                $chain = @($current.chain) + @([pscustomobject]@{ from = $currentNode.path; to = $reference.path; stops = $reference.stops })
                $reached.Add($reference.path, $chain)
                $frontier.Enqueue([pscustomobject]@{ path = $reference.path; chain = $chain })
            }
        }
    }
    foreach ($targetPath in @($reached.Keys | Sort-Object)) {
        if (-not $nodes.ContainsKey($targetPath)) { continue }
        $target = $nodes[$targetPath]
        if ($target.ring -ceq 'Outside' -or $target.ring -ceq $root.ring -or
            @($policy.allowedDependencies.PSObject.Properties[$root.ring].Value) -contains $target.ring) { continue }
        $chain = @($reached[$targetPath])
        $kind = if ($chain.Count -eq 1) { 'direct' } else { 'transitive' }
        $pathNames = @($root.name) + @($chain | ForEach-Object { $nodes[$_.to].name })
        $from = [IO.Path]::GetRelativePath($targetRoot, $root.path).Replace('\', '/')
        $to = [IO.Path]::GetRelativePath($targetRoot, $target.path).Replace('\', '/')
        $findings.Add([ordered]@{
            ruleId = $ruleId
            subject = "$from -> $to [$kind`: $($pathNames -join ' > ')]"
            evidenceKind = 'project-graph-raw'
            detectorId = $detectorId
            severity = 'blocking'
        })
    }
}
if ($domainMatched -eq 0) {
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
