[CmdletBinding()]
param(
    [string] $InventoryPath = 'docs/architecture/review/evidence/plan04/module-boundary-inventory.json',
    [string] $GraphPath = 'docs/architecture/review/evidence/plan04/module-boundary-dependency-graph.json',
    [string] $StatusPath = 'docs/architecture/review/evidence/plan04/phase1-inventory-status.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
function Repo([string] $path) {
    if ([IO.Path]::IsPathRooted($path)) { return $path }
    return Join-Path $repositoryRoot $path
}
function Sha256([string] $path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath (Repo $path)).Hash.ToLowerInvariant()
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
)
$checks = [ordered]@{
    deterministicGeneration = $firstHash -eq $secondHash -and $firstGraphHash -eq $secondGraphHash
    exactBusinessModuleSet = @(Compare-Object $expectedModules @($inventory.modules.id)).Count -eq 0
    modulesReconcileG02G03G04 = @($inventory.modules | Where-Object {
        [string]::IsNullOrWhiteSpace($_.owner) -or [string]::IsNullOrWhiteSpace($_.schema) -or
        [string]::IsNullOrWhiteSpace($_.dbContext) -or [string]::IsNullOrWhiteSpace($_.releaseVersion) -or
        @($_.capabilities).Count -eq 0 -or @($_.dataFacts).Count -eq 0 -or @($_.endpointGroups).Count -eq 0
    }).Count -eq 0
    exactActiveProtocolSet = @(Compare-Object $expectedProtocols @($inventory.protocolEdges.identity)).Count -eq 0 -and
        @($inventory.protocolEdges | Where-Object lifecycle -ne 'Active').Count -eq 0
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
    authorityHashesMatchPhase0 = $inventory.inputs.g02DatabaseInventorySha256 -eq '0314377c7c1f7e5072a465ec2d50db8e8affef53f876ee19747c688e1781b7a5' -and
        $inventory.inputs.g03CatalogSha256 -eq '07f10e3741796d7c60651c30fdf0d0f04a602e54cf316b1bb759bfd4e9230429' -and
        $inventory.inputs.g04ModuleManifestSha256 -eq '4047c3209d3faa66d0398b7a5c1cdcaa855d329f471363bf430b33747e495860' -and
        $inventory.inputs.b4DependencyGraphSha256 -eq '1cf5a645ddd9ef429c2597a9464b575eb37317a2b2706bf6f93116016632be36'
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
