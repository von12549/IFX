# IFX I2-B (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) amendment A1 preparation: classify every target path
# that a 0.4.4 Post module binds, by the pin split rule accepted at B3 (design note 12, finding F3). The classes are
# assigned by ordered path rules; "unclassified" paths need an operator ruling.
#   governance       keep the Profile pin; the file changes only through a bundle update
#   live-source      drop the pin; the module's checks run on the current content
#   live-registry    drop the pin; the registry is reconciled with the current source (changes with ordinary work)
#   v3-coupling      replace: V3-generated data or V3 tool data
#   lab-coupling     replace: reads docs/guards/candidates; embed into the module
#   provenance-only  a recorded rule origin (source* keys), compared as a string and never read; not a pin
[CmdletBinding()]
param(
    [string]$InstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6-ifx-0.4.4',
    [Parameter(Mandatory)][string]$OutputPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $OutputPath) { throw "Output already exists: $OutputPath" }
$package = Join-Path $InstallRoot 'package'
$profilePath = Join-Path $package 'profiles/catalog/ifx_profile/profile.json'
$profile = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json -Depth 100
$post = @($profile.stageConfiguration.post.modules)
$rules = @(
    @{ class = 'lab-coupling'; pattern = '^docs/guards/candidates/' }
    @{ class = 'v3-coupling'; pattern = '(?i)^docs/guards/V3|^mcp/LayerGuard/|/generated/layerguard-governance-input\.json$' }
    @{ class = 'live-registry'; pattern = '^docs/architecture/review/gates/G03/(contract-event-catalog\.yaml|snapshots/)|^docs/architecture/review/policies/.*registry[^/]*\.json$' }
    @{ class = 'live-source'; pattern = '^(src|tests|deployment)(/|$)|^docker-compose[^/]*\.yml$|^IFX\.sln$|^Directory\.[^/]+$|^\.github/CODEOWNERS$' }
    @{ class = 'governance'; pattern = '^docs/architecture/review/|^\.claude/Plans/' }
)
function Classify([string]$Path) { foreach ($r in $rules) { if ($Path -cmatch $r.pattern) { return $r.class } }; 'unclassified' }
$repoPath = '^(src|tests|docs|deployment|mcp|\.claude|\.github)(/|$)|^IFX\.sln$|^docker-compose[^/]*\.yml$|^Directory\.[^/]+$'
function Collect($Node, [string]$Key, [Collections.Generic.Dictionary[string, string]]$Into) {
    # Records each repository path with the first JSON key path that names it (for example "sourceScripts[].path").
    if ($null -eq $Node) { return }
    if ($Node -is [string]) { if ($Node -cmatch $repoPath -and $Node -notmatch '[\s*?]') { $k = $Node.TrimEnd('/'); if (-not $Into.ContainsKey($k)) { $Into[$k] = $Key } }; return }
    if ($Node -is [System.Collections.IEnumerable] -and $Node -isnot [string]) { foreach ($i in $Node) { Collect $i "$Key[]" $Into }; return }
    if ($Node -is [pscustomobject]) { foreach ($p in $Node.PSObject.Properties) { Collect $p.Value $(if ($Key) { "$Key.$($p.Name)" } else { $p.Name }) $Into } }
}
# Provenance keys (source*) record where a rule came from. When the adapter never names the key, the path is only
# a recorded string and not a pin (A6, I2-A); when it does (ifx-c1-evaluated-reference reads sourcePolicies), the
# coupling is real. History-integrity entries are fixed historical records.
function Refine([string]$Class, [string]$Key, [string]$Module) {
    $top = ($Key -split '[.\[]')[0]
    $adapter = Join-Path $package "modules/$Module/adapter.ps1"
    $named = (Test-Path -LiteralPath $adapter) -and ([IO.File]::ReadAllText($adapter) -cmatch "\b$([regex]::Escape($top))\b")
    if ($top -cmatch '^source[A-Z]\w*$|^sourcePolicies$|^sourceScripts?$' -and $Class -in @('v3-coupling', 'lab-coupling') -and -not $named) { return 'provenance-only' }
    if ($Module -ceq 'ifx-history-integrity' -and $Key -cmatch '^entries\[\]\.path$') { return 'governance' }
    $Class
}
$modules = [Collections.Generic.List[object]]::new()
foreach ($selection in $profile.moduleSelections) {
    if ($post -notcontains $selection.id) { continue }
    $policyPath = Join-Path $package "modules/$($selection.id)/policy.json"
    $paths = [Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
    if (Test-Path -LiteralPath $policyPath) { Collect (Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json -Depth 100) '' $paths }
    $c = $selection.config; $names = @($c.PSObject.Properties.Name)
    $trees = @($names | Where-Object { $_ -match 'TreeSha256$' })
    $sorted = [Collections.Generic.List[string]]::new([string[]]@($paths.Keys)); $sorted.Sort([StringComparer]::Ordinal)
    $rows = @($sorted | ForEach-Object { [ordered]@{ path = $_; key = $paths[$_]; class = (Refine (Classify $_) $paths[$_] $selection.id) } })
    $counts = [ordered]@{}; foreach ($r in $rows) { $counts[$r.class] = 1 + $(if ($counts.Contains($r.class)) { $counts[$r.class] } else { 0 }) }
    $modules.Add([ordered]@{
        module = $selection.id
        evidenceLock = $names -contains 'evidenceLockPath'
        profileAuthorityHashes = $(if ($names -contains 'authorityHashes') { @($c.authorityHashes).Count } else { 0 })
        profileTreeFingerprints = $trees
        classCounts = $counts
        paths = $rows
    })
}
$all = @($modules | ForEach-Object { $_.paths } | ForEach-Object { $_ })
$totals = [ordered]@{}; foreach ($r in $all) { $totals[$r.class] = 1 + $(if ($totals.Contains($r.class)) { $totals[$r.class] } else { 0 }) }
$distinct = [ordered]@{}; foreach ($g in @($all | Group-Object { $_.class })) { $distinct[$g.Name] = @($g.Group | ForEach-Object { $_.path } | Sort-Object -Unique).Count }
$record = [ordered]@{
    formatVersion = 1; kind = 'ifx-i2b-a1-pin-classification'
    profile = [ordered]@{ version = $profile.version; sha256 = (Get-FileHash -LiteralPath $profilePath -Algorithm SHA256).Hash.ToLowerInvariant() }
    rules = @($rules | ForEach-Object { [ordered]@{ class = $_.class; pattern = $_.pattern } })
    totals = [ordered]@{ modulePathRows = $totals; distinctPaths = $distinct }
    unclassified = @($all | Where-Object { $_.class -ceq 'unclassified' } | ForEach-Object { $_.path } | Sort-Object -Unique)
    modules = @($modules.ToArray())
}
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($OutputPath)))
[IO.File]::WriteAllText($OutputPath, (($record | ConvertTo-Json -Depth 10).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
$modules | ForEach-Object { "{0,-30} lock={1,-5} {2}" -f $_.module, $_.evidenceLock, (($_.classCounts.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' ') }
"distinct: $(($distinct.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' ')"
"unclassified: $(@($record.unclassified) -join ', ')"
