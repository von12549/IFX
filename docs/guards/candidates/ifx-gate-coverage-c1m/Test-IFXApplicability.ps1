param(
    [Parameter(Mandatory)][string] $RepositoryRoot,
    [Parameter(Mandatory)][string] $TargetRoot,
    [string] $DecisionPath = 'docs/guards/inventories/20260924-ifx-c1-applicability-decisions.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fail([string] $Category, [string] $Reason) {
    [Console]::Out.WriteLine((@{ status = 'fail'; category = $Category; reason = $Reason } | ConvertTo-Json -Compress))
    exit 1
}
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    return $relative -ne '..' -and -not [IO.Path]::IsPathRooted($relative) -and
        -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal)
}
function Assert-NoLink([string] $Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current -and ([IO.File]::Exists($current) -or [IO.Directory]::Exists($current))) {
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) {
            Fail 'unsafe-path' 'A project or authority path contains a link.'
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if (-not $parent -or $parent -ceq $current) { break }
        $current = $parent
    }
}
function Hash([string] $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Resolve-Relative([string] $Root, [string] $Relative) {
    if ([IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)') {
        Fail 'invalid-decision' 'An authority or project path is not a safe relative path.'
    }
    $path = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (-not (Is-Under $path $Root)) { Fail 'invalid-decision' 'A decision path escapes its root.' }
    return $path
}
function Matches([string] $Name, [string] $Pattern) {
    $expression = '^' + [regex]::Escape($Pattern).Replace('\*', '.*') + '$'
    return [regex]::IsMatch($Name, $expression, [Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

$repo = [IO.Path]::GetFullPath($RepositoryRoot)
$target = [IO.Path]::GetFullPath($TargetRoot)
if (-not [IO.Directory]::Exists($repo) -or -not [IO.Directory]::Exists($target)) { Fail 'prerequisite-missing' 'RepositoryRoot or TargetRoot is missing.' }
Assert-NoLink $repo
Assert-NoLink $target
$decisionFile = Resolve-Relative $repo $DecisionPath
if (-not [IO.File]::Exists($decisionFile)) { Fail 'prerequisite-missing' 'The applicability decision is missing.' }
Assert-NoLink $decisionFile
try { $decision = Get-Content -LiteralPath $decisionFile -Raw | ConvertFrom-Json -Depth 30 }
catch { Fail 'invalid-decision' 'The applicability decision is malformed.' }
if ($decision.formatVersion -ne 1 -or $decision.id -cne 'ifx-c1m-applicability-decisions' -or
    $decision.l29.choice -cne 'A' -or $decision.integrationAdapter.choice -cne 'A' -or
    $decision.integrationAdapter.scanRoot -cne 'src' -or $decision.integrationAdapter.adapterProjectCount -ne 0) {
    Fail 'invalid-decision' 'The applicability decision identity or scope has drifted.'
}
foreach ($authority in @($decision.l29.authority)) {
    $path = Resolve-Relative $repo ([string]$authority.path)
    if (-not [IO.File]::Exists($path)) { Fail 'prerequisite-missing' "Missing authority: $($authority.path)" }
    Assert-NoLink $path
    if ((Hash $path) -cne [string]$authority.sha256) { Fail 'authority-drift' "Authority changed: $($authority.path)" }
}
$policyPath = [string]$decision.integrationAdapter.sourcePolicyPath
$policyFile = Resolve-Relative $repo $policyPath
if ($policyPath -cne 'docs/guards/V3_ifx/stages/post/policy/layerguard.json' -or
    (Hash $policyFile) -cne [string]$decision.integrationAdapter.sourcePolicySha256) {
    Fail 'authority-drift' 'IntegrationAdapter policy path or hash changed.'
}
try { $policy = Get-Content -LiteralPath $policyFile -Raw | ConvertFrom-Json -Depth 30 }
catch { Fail 'authority-drift' 'IntegrationAdapter policy is malformed.' }
if (-not $policy.ownership.requireKnown -or
    (@($policy.rings.IntegrationAdapter) -join '|') -cne (@($decision.integrationAdapter.ringPatterns) -join '|')) {
    Fail 'authority-drift' 'Ownership or IntegrationAdapter policy facts changed.'
}
$sourceRoot = Resolve-Relative $target 'src'
if (-not [IO.Directory]::Exists($sourceRoot)) { Fail 'prerequisite-missing' 'TargetRoot/src is missing.' }
Assert-NoLink $sourceRoot
$skip = @($decision.integrationAdapter.excludedDirectoryNames)
if (($skip -join '|') -cne 'guard|guards|generated|obj|bin|.git') { Fail 'invalid-decision' 'Discovery exclusions changed.' }
$stack = [Collections.Generic.Stack[string]]::new()
$stack.Push($sourceRoot)
$actual = [Collections.Generic.List[object]]::new()
$adapterPaths = [Collections.Generic.List[string]]::new()
while ($stack.Count -gt 0) {
    $dir = $stack.Pop()
    foreach ($item in @(Get-ChildItem -LiteralPath $dir -Force | Sort-Object Name)) {
        if ($item.PSIsContainer) {
            if ($item.Name -in $skip) { continue }
            Assert-NoLink $item.FullName
            $stack.Push($item.FullName)
        }
        elseif ($item.Name.EndsWith('.csproj', [StringComparison]::OrdinalIgnoreCase)) {
            Assert-NoLink $item.FullName
            $relative = [IO.Path]::GetRelativePath($target, $item.FullName).Replace('\', '/')
            $actual.Add([pscustomobject]@{ path = $relative; sha256 = (Hash $item.FullName) })
            if (@($policy.rings.IntegrationAdapter | Where-Object { Matches $item.BaseName ([string]$_) }).Count -gt 0) {
                $adapterPaths.Add($relative)
            }
            if (-not [IO.Path]::GetFileName([IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName($item.FullName)))) {
                Fail 'l29-applicability-drift' 'A project lacks the V3 parent-folder module fallback.'
            }
        }
    }
}
if ($adapterPaths.Count -gt 0) { Fail 'adapter-present' "IntegrationAdapter project exists: $($adapterPaths[0])" }
$rows = @($actual.ToArray() | Sort-Object path -CaseSensitive)
$expected = @($decision.integrationAdapter.projects)
if ($rows.Count -ne [int]$decision.integrationAdapter.projectCount -or $expected.Count -ne $rows.Count) {
    Fail 'inventory-drift' 'Project count changed.'
}
for ($i = 0; $i -lt $rows.Count; $i++) {
    if ($rows[$i].path -cne [string]$expected[$i].path -or $rows[$i].sha256 -cne [string]$expected[$i].sha256) {
        Fail 'inventory-drift' "Project path or content changed at index $i."
    }
}
$lines = @($rows | ForEach-Object { "$($_.path)|$($_.sha256)" })
$bytes = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n") + "`n")
$digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
if ($digest -cne [string]$decision.integrationAdapter.inventorySha256) { Fail 'invalid-decision' 'Inventory digest is inconsistent.' }
[Console]::Out.WriteLine((@{ status = 'pass'; decisionId = $decision.id; projectCount = $rows.Count; adapterProjectCount = 0; inventorySha256 = $digest; l29 = 'V3-null-module-unreachable-under-frozen-scope' } | ConvertTo-Json -Compress))
