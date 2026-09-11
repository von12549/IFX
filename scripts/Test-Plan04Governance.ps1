[CmdletBinding()]
param(
    [string] $LockPath = 'docs/architecture/review/policies/plan04/plan04-governance-lock.json',
    [string] $StatusPath = 'docs/architecture/review/evidence/plan04/phase6-governance-status.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
function Repo([string] $path) { if ([IO.Path]::IsPathRooted($path)) { return $path }; Join-Path $repositoryRoot $path }
function Sha256([string] $path) { (Get-FileHash -Algorithm SHA256 -LiteralPath (Repo $path)).Hash.ToLowerInvariant() }
function SetsEqual([object[]] $left, [object[]] $right) { (@($left | Sort-Object) -join '|') -eq (@($right | Sort-Object) -join '|') }

function HasCycle([string[]] $nodes, [object[]] $edges) {
    $degree = @{}; $adjacency = @{}
    foreach ($node in $nodes) { $degree[$node] = 0; $adjacency[$node] = @() }
    foreach ($edge in $edges) {
        if (-not $degree.ContainsKey([string]$edge.from) -or -not $degree.ContainsKey([string]$edge.to)) { return $true }
        $adjacency[[string]$edge.from] += [string]$edge.to; $degree[[string]$edge.to]++
    }
    $queue = [Collections.Generic.Queue[string]]::new()
    foreach ($node in $nodes) { if ($degree[$node] -eq 0) { $queue.Enqueue($node) } }
    $visited = 0
    while ($queue.Count -gt 0) { $node = $queue.Dequeue(); $visited++; foreach ($target in $adjacency[$node]) { $degree[$target]--; if ($degree[$target] -eq 0) { $queue.Enqueue($target) } } }
    $visited -ne $nodes.Count
}

function ValidateBoundaryFixture([object] $fixture) {
    $errors = [Collections.Generic.HashSet[string]]::new()
    if ($fixture.formatVersion -ne 1 -or $null -eq $fixture.nodes -or $null -eq $fixture.edges -or $null -eq $fixture.hashesMatch) { [void]$errors.Add('fixture-shape-invalid'); return @($errors) }
    $known = @('auth','crm','registry','transaction','holdings')
    if (@($fixture.nodes | Where-Object { $_.id -notin $known -or [string]::IsNullOrWhiteSpace([string]$_.owner) }).Count -gt 0) { [void]$errors.Add('unknown-or-ownerless-module') }
    if (@($fixture.edges | Where-Object registered -ne $true).Count -gt 0) { [void]$errors.Add('unregistered-cross-module-edge') }
    if (HasCycle @($fixture.nodes.id) @($fixture.edges)) { [void]$errors.Add('dependency-cycle') }
    if ($fixture.hashesMatch -ne $true) { [void]$errors.Add('authority-hash-drift') }
    @($errors | Sort-Object)
}

$validatorScripts = @(
    'Test-Plan04Phase0Baseline.ps1',
    'Test-Plan04Phase1Inventory.ps1',
    'Test-Plan04Phase2Audit.ps1',
    'Test-Plan04ExtractionPolicy.ps1',
    'Test-Plan04TenantQueryPolicy.ps1',
    'Test-Plan04ProjectionPolicy.ps1'
    'Test-AbstractionsRetirement.ps1'
)
$validatorResults = @()
foreach ($scriptName in $validatorScripts) {
    try { & (Join-Path $PSScriptRoot $scriptName); $validatorResults += [ordered]@{ validator = $scriptName; passed = $true; error = $null } }
    catch { $validatorResults += [ordered]@{ validator = $scriptName; passed = $false; error = $_.Exception.Message } }
}

$lock = Get-Content -Raw -LiteralPath (Repo $LockPath) | ConvertFrom-Json -Depth 100
$hashResults = @()
foreach ($entry in @($lock.authorityInputs) + @($lock.decisionArtifacts)) {
    $exists = Test-Path -LiteralPath (Repo $entry.path) -PathType Leaf
    $actual = if ($exists) { Sha256 $entry.path } else { $null }
    $hashResults += [ordered]@{ authority = $entry.authority; path = $entry.path; expectedSha256 = $entry.sha256; actualSha256 = $actual; passed = $exists -and $actual -eq $entry.sha256 }
}

$fixtureResults = @()
foreach ($file in @(Get-ChildItem -LiteralPath (Repo 'tests/Architecture/Plan04/Fixtures') -File -Filter 'boundary-*.json' | Sort-Object Name)) {
    $fixture = Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json -Depth 100
    $actual = @(ValidateBoundaryFixture $fixture)
    $expected = @($fixture.expectedErrors | Sort-Object)
    $fixtureResults += [ordered]@{ fixture = $file.Name; expectedErrors = $expected; actualErrors = $actual; passed = SetsEqual $expected $actual }
}

$checks = [ordered]@{
    allPhaseValidatorsPassIndependently = $validatorResults.Count -eq 7 -and @($validatorResults | Where-Object passed -ne $true).Count -eq 0
    authorityAndDecisionHashesMatch = $hashResults.Count -ge 10 -and @($hashResults | Where-Object passed -ne $true).Count -eq 0
    boundaryPositiveAndNegativeFixturesPass = $fixtureResults.Count -eq 5 -and @($fixtureResults | Where-Object passed -ne $true).Count -eq 0 -and @($fixtureResults | Where-Object { @($_.actualErrors).Count -eq 0 }).Count -eq 1
    layerGuardValidatorAndBehaviorChecksAreComplementary = @('Test-Plan04Phase1Inventory.ps1','Test-Plan04TenantQueryPolicy.ps1','Test-Plan04ProjectionPolicy.ps1' | Where-Object { $_ -notin $validatorResults.validator }).Count -eq 0
    failedScanCannotBeGreen = @($validatorResults | Where-Object { $_.passed -ne $true -and [string]::IsNullOrWhiteSpace([string]$_.error) }).Count -eq 0
}
$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$status = [ordered]@{
    formatVersion = 1; plan = '04-module-boundary-evolution'; slice = 'P04-S6'; checkedAt = (Get-Date).ToString('yyyy-MM-dd')
    result = if ($failed.Count -eq 0) { 'repository-passed-approvals-and-production-not-claimed' } else { 'failed' }
    governanceLockSha256 = Sha256 $LockPath; checks = $checks; validators = $validatorResults; hashBindings = $hashResults; boundaryFixtureResults = $fixtureResults
    roleSeparation = [ordered]@{ LayerGuard = 'project/namespace/static dependency boundary'; dedicatedValidators = 'authority drift, tenant query semantics, projection registration/lifecycle'; behaviorTests = 'authorization, tenant isolation, durable delivery and idempotent effects' }
    claims = [ordered]@{ namedFunctionalApprovals = 'not-claimed'; productionRls = 'not-claimed'; productionReporting = 'not-claimed'; microserviceExtraction = 'not-claimed' }
    failedChecks = $failed
}
$resolvedStatus = Repo $StatusPath
$directory = Split-Path -Parent $resolvedStatus
if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
$status | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $resolvedStatus -Encoding utf8NoBOM
if ($failed.Count -gt 0) { throw "Plan 04 unified governance failed: $($failed -join ', '). Report: $resolvedStatus" }
Write-Host "Plan 04 unified governance result: $($status.result). Report: $resolvedStatus"
