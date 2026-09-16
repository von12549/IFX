[CmdletBinding()]
param(
    [string] $InventoryPath = 'docs/architecture/review/evidence/plan04/module-boundary-inventory.json',
    [string] $GraphPath = 'docs/architecture/review/evidence/plan04/module-boundary-dependency-graph.json',
    [string] $StatusPath = 'docs/architecture/review/evidence/plan04/phase1-inventory-status.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = if ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..')) }
function Repo([string] $path) {
    if ([IO.Path]::IsPathRooted($path)) { return $path }
    return Join-Path $repositoryRoot $path
}
function Sha256([string] $path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath (Repo $path)).Hash.ToLowerInvariant()
}
function GovernedHash([string] $path) {
    $lock = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/policies/plan04/plan04-governance-lock.json') | ConvertFrom-Json -Depth 100
    $entries = @($lock.authorityInputs | Where-Object path -eq $path)
    if ($entries.Count -ne 1) { throw "Expected one governed authority binding for $path" }
    return $entries[0].sha256
}

& (Join-Path $PSScriptRoot 'New-Plan04BoundaryInventory.ps1') -OutputPath $InventoryPath -GraphPath $GraphPath
$firstHash = Sha256 $InventoryPath
$firstGraphHash = Sha256 $GraphPath
& (Join-Path $PSScriptRoot 'New-Plan04BoundaryInventory.ps1') -OutputPath $InventoryPath -GraphPath $GraphPath
$secondHash = Sha256 $InventoryPath
$secondGraphHash = Sha256 $GraphPath
$inventory = Get-Content -Raw -LiteralPath (Repo $InventoryPath) | ConvertFrom-Json -Depth 100
$graph = Get-Content -Raw -LiteralPath (Repo $GraphPath) | ConvertFrom-Json -Depth 100

$expectedModules = @('auth','crm','registry','transaction','holdings')
$expectedProtocols = @(
    'crm.account-compliance.v1',
    'registry.class-subscription-availability.v1',
    'ifx.registry.class-status-changed.v1',
    'ifx.transaction.transaction-processed.v1'
    'auth.resource-authorization.v1'
    'auth.resource-authorization.v1'
    'auth.resource-authorization.v1'
    'auth.resource-authorization.v1'
)
$checks = [ordered]@{
    deterministicGeneration = $firstHash -eq $secondHash -and $firstGraphHash -eq $secondGraphHash
    exactBusinessModuleSet = @(Compare-Object $expectedModules @($inventory.modules.id)).Count -eq 0
    modulesReconcileG02G03G04 = @($inventory.modules | Where-Object {
        [string]::IsNullOrWhiteSpace($_.owner) -or [string]::IsNullOrWhiteSpace($_.schema) -or
        [string]::IsNullOrWhiteSpace($_.dbContext) -or [string]::IsNullOrWhiteSpace($_.releaseVersion) -or
        @($_.capabilities).Count -eq 0 -or @($_.dataFacts).Count -eq 0 -or @($_.endpointGroups).Count -eq 0
    }).Count -eq 0
    exactGovernedProtocolSet = @(Compare-Object $expectedProtocols @($inventory.protocolEdges.identity)).Count -eq 0 -and
        @($inventory.protocolEdges | Where-Object {
            if ($_.identity -eq 'auth.resource-authorization.v1') { $_.lifecycle -ne 'Proposed' }
            else { $_.lifecycle -ne 'Active' }
        }).Count -eq 0
    graphIsAuthorityDerived = @(Compare-Object $expectedModules @($graph.nodes.id)).Count -eq 0 -and
        @(Compare-Object $expectedProtocols @($graph.protocolEdges.identity)).Count -eq 0 -and
        @($graph.physicalCrossModuleEdges | Where-Object classification -ne 'registered-cross-module-protocol').Count -eq 0
    crossModuleEdgesAreCatalogRegistered = @($inventory.failClosedFindings.unregisteredCrossModuleProjectEdges).Count -eq 0
    noUnknownBusinessModules = @($inventory.failClosedFindings.unknownSourceModules).Count -eq 0
    noCrossSchemaDataAccess = @($inventory.failClosedFindings.crossSchemaDataAccess).Count -eq 0
    metricsAreReviewOnly = @($inventory.modules | Where-Object {
        $null -eq $_.metrics.physicalFanInModules -or $null -eq $_.metrics.physicalFanOutModules -or
        $null -eq $_.metrics.commitsInHistoryWindow -or $null -eq $_.assessmentSignals.dataOwnershipRecorded
    }).Count -eq 0 -and $inventory.runtimeAndDataCoupling.independentModuleRelease -eq 'not-supported'
    everyModuleHasIndependentTests = @($inventory.modules | Where-Object { -not $_.assessmentSignals.independentTestsPresent }).Count -eq 0
    sharedRuntimeAndDataCouplingExplicit = $inventory.runtimeAndDataCoupling.businessReleaseBoundary -eq 'single-required-five-module-release' -and
        $inventory.runtimeAndDataCoupling.schemaOwnership -eq 'module-owned' -and
        $inventory.runtimeAndDataCoupling.crossSchemaAccess -eq 'none-detected'
    authorityHashesMatchGovernedBindings = $inventory.inputs.g02DatabaseInventorySha256 -eq (GovernedHash 'docs/architecture/review/evidence/gates/G02/G02-database-inventory.json') -and
        $inventory.inputs.g03CatalogSha256 -eq (GovernedHash 'docs/architecture/review/gates/G03/contract-event-catalog.yaml') -and
        $inventory.inputs.g04ModuleManifestSha256 -eq (GovernedHash 'deployment/g04/module-manifest.json') -and
        $inventory.inputs.b4DependencyGraphSha256 -eq (GovernedHash 'docs/architecture/review/evidence/plan05/current-dependency-graph.json')
}

$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$status = [ordered]@{
    formatVersion = 1
    plan = '04-module-boundary-evolution'
    slice = 'P04-S1'
    result = if ($failed.Count -eq 0) { 'passed' } else { 'failed' }
    checkedAt = (Get-Date).ToString('yyyy-MM-dd')
    inventorySha256 = $secondHash
    dependencyGraphSha256 = $secondGraphHash
    counts = [ordered]@{
        modules = @($inventory.modules).Count
        protocols = @($inventory.protocolEdges).Count
        projectEdges = @($inventory.projectEdges).Count
        namespaceEdges = @($inventory.namespaceEdges).Count
        coChangePairs = @($inventory.changeCoupling.pairs).Count
        unregisteredEdges = @($inventory.failClosedFindings.unregisteredCrossModuleProjectEdges).Count
        crossSchemaFindings = @($inventory.failClosedFindings.crossSchemaDataAccess).Count
    }
    checks = $checks
    failedChecks = $failed
    interpretation = 'Metrics support review only and do not authorize extraction.'
    productionClaims = [ordered]@{
        independentModuleRelease = 'not-claimed'
        microserviceExtraction = 'not-claimed'
        productionReporting = 'not-claimed'
    }
}

$resolvedStatus = Repo $StatusPath
$status | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $resolvedStatus -Encoding utf8NoBOM
if ($failed.Count -gt 0) {
    throw "Plan 04 Phase 1 inventory validation failed: $($failed -join ', '). Report: $resolvedStatus"
}
Write-Host "Plan 04 Phase 1 inventory validation passed. Report: $resolvedStatus"
