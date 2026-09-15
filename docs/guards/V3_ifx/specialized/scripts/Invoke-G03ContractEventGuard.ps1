[CmdletBinding()]
param(
    [ValidateRange(0, 9)]
    [int] $Phase = 0,
    [string] $ReportPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = "artifacts/guards/v3-ifx/specialized/g03/G03-phase$Phase-guard-report.json"
}
$resolvedReportPath = if ([System.IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $repositoryRoot $ReportPath }
$outputRoot = Split-Path -Parent $resolvedReportPath
$inventoryPath = Join-Path $outputRoot 'G03-contract-event-inventory.json'
$generator = Join-Path $PSScriptRoot 'Invoke-G03ContractEventInventory.ps1'

New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
& $generator -ReportPath $inventoryPath
$firstHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryPath).Hash.ToLowerInvariant()
& $generator -ReportPath $inventoryPath
$secondHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryPath).Hash.ToLowerInvariant()
$inventory = Get-Content -Raw -LiteralPath $inventoryPath | ConvertFrom-Json -Depth 100
    $catalogReportPath = Join-Path $outputRoot "G03-phase$Phase-catalog-report.json"
$catalogPassed = $true
if ($Phase -ge 1) {
    & (Join-Path $PSScriptRoot 'Test-G03ContractEventCatalog.ps1') -ReportPath $catalogReportPath -SelfTest
    $catalogResult = Get-Content -Raw -LiteralPath $catalogReportPath | ConvertFrom-Json -Depth 100
    $catalogPassed = $catalogResult.result -eq 'passed'
}
$surfaceReconciled = $true
$missingCatalogSurface = @()
$unknownCatalogSurface = @()
if ($Phase -ge 2) {
    $catalog = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/architecture/review/gates/G03/contract-event-catalog.yaml') | ConvertFrom-Json -Depth 100
    $sourceKeys = @()
    foreach ($surface in @($inventory.publicSurface | Where-Object project -like '*.Abstractions')) {
        $sourceKeys += "$($surface.project)|$($surface.name)|"
        foreach ($method in @($surface.methods)) { $sourceKeys += "$($surface.project)|$($surface.name)|$($method.name)" }
    }
    $catalogKeys = @($catalog.publicSurface | Where-Object lifecycle -eq 'LegacyPendingMigration' | ForEach-Object { "$($_.project)|$($_.type)|$($_.member)" })
    $missingCatalogSurface = @($sourceKeys | Where-Object { $_ -notin $catalogKeys } | Sort-Object -Unique)
    $unknownCatalogSurface = @($catalogKeys | Where-Object { $_ -notin $sourceKeys } | Sort-Object -Unique)
    $expectedLegacySurfaceCount = if ($Phase -ge 6) { 0 } else { 20 }
    $surfaceReconciled = $missingCatalogSurface.Count -eq 0 -and $unknownCatalogSurface.Count -eq 0 -and $catalogKeys.Count -eq $expectedLegacySurfaceCount
}
$sourceReconciliation = $true
$deterministicSnapshots = $true
$layerGuardHandoff = $true
$documentationPassed = $true
$closeoutAuditPassed = $true
$closeoutStatus = $null
if ($Phase -ge 6) {
    $sourceReportPath = Join-Path $outputRoot "G03-phase$Phase-source-reconciliation.json"
    & (Join-Path $PSScriptRoot 'Invoke-G03SourceReconciliation.ps1') -ReportPath $sourceReportPath
    $sourceResult = Get-Content -Raw -LiteralPath $sourceReportPath | ConvertFrom-Json -Depth 100
    $sourceReconciliation = $sourceResult.result -eq 'passed'
    $apiPath = Join-Path $outputRoot 'G03-sync-api-snapshot.json'
    $schemaPath = Join-Path $outputRoot 'G03-serialization-golden.json'
    & (Join-Path $PSScriptRoot 'Invoke-G03CompatibilitySnapshots.ps1') -ApiSnapshotPath $apiPath -SerializationSnapshotPath $schemaPath
    $firstSnapshotHash = "$((Get-FileHash $apiPath -Algorithm SHA256).Hash)|$((Get-FileHash $schemaPath -Algorithm SHA256).Hash)"
    & (Join-Path $PSScriptRoot 'Invoke-G03CompatibilitySnapshots.ps1') -ApiSnapshotPath $apiPath -SerializationSnapshotPath $schemaPath
    $secondSnapshotHash = "$((Get-FileHash $apiPath -Algorithm SHA256).Hash)|$((Get-FileHash $schemaPath -Algorithm SHA256).Hash)"
    $deterministicSnapshots = $firstSnapshotHash -eq $secondSnapshotHash
}
if ($Phase -ge 7) {
    $handoffReportPath = Join-Path $outputRoot "G03-phase$Phase-layerguard-handoff-report.json"
    & (Join-Path $PSScriptRoot 'Test-G03LayerGuardGovernance.ps1') -ReportPath $handoffReportPath
    $handoffResult = Get-Content -Raw -LiteralPath $handoffReportPath | ConvertFrom-Json -Depth 100
    $layerGuardHandoff = $handoffResult.result -eq 'passed'
}
if ($Phase -ge 8) {
    $documentationReportPath = Join-Path $outputRoot "G03-phase$Phase-documentation-report.json"
    & (Join-Path $PSScriptRoot 'Test-G03Documentation.ps1') -ReportPath $documentationReportPath
    $documentationResult = Get-Content -Raw -LiteralPath $documentationReportPath | ConvertFrom-Json -Depth 100
    $documentationPassed = $documentationResult.result -eq 'passed'
}
if ($Phase -ge 9) {
    $closeoutReportPath = Join-Path $outputRoot 'G03-phase9-status.json'
    & (Join-Path $PSScriptRoot 'Test-G03CloseoutReadiness.ps1') -ReportPath $closeoutReportPath
    $closeoutResult = Get-Content -Raw -LiteralPath $closeoutReportPath | ConvertFrom-Json -Depth 100
    $closeoutAuditPassed = $closeoutResult.result -eq 'passed'
    $closeoutStatus = $closeoutResult.closureStatus
}

$checks = [ordered]@{
    deterministicInventory = $firstHash -eq $secondHash
    legacyAbstractionProjectsRetired = $inventory.counts.abstractionProjects -eq 0
    exactCurrentReaderCount = $inventory.counts.readers -eq 4
    exactCurrentReaderMethodCount = $inventory.counts.readerMethods -eq 4
    exactDtoCount = $inventory.counts.dtos -eq 0
    exactIntegrationEventCount = $inventory.counts.integrationEvents -eq $(if ($Phase -ge 6) { 2 } else { 20 })
    messagingSurfaceInventoried = $inventory.counts.messagingAbstractionTypes -eq 4
    generatedDirectoriesExcluded = @($inventory.publicSurface.declaration.file | Where-Object { $_ -match '(^|/)(bin|obj)/' }).Count -eq 0
    catalogValidation = $catalogPassed
    publicSurfaceReconciliation = $surfaceReconciled
    sourceCatalogReconciliation = $sourceReconciliation
    deterministicCompatibilitySnapshots = $deterministicSnapshots
    layerGuardGovernanceHandoff = $layerGuardHandoff
    bilingualDocumentationAndRenderedDiagrams = $documentationPassed
    closeoutReadinessAudit = $closeoutAuditPassed
}

$report = [ordered]@{
    formatVersion = 1
    gate = 'G03'
    phase = $Phase
    result = if ($checks.Values -contains $false) { 'failed' } else { 'passed' }
    checks = $checks
    counts = $inventory.counts
    sha256 = [ordered]@{ inventory = $secondHash }
    failures = [ordered]@{ missingCatalogSurface = $missingCatalogSurface; unknownCatalogSurface = $unknownCatalogSurface }
    closureStatus = $closeoutStatus
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedReportPath -Encoding utf8NoBOM
if ($report.result -ne 'passed') { throw "G03 Phase $Phase guard failed. Report: $resolvedReportPath" }
Write-Host "G03 Phase $Phase guard passed. Report: $resolvedReportPath"
