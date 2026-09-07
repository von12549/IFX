[CmdletBinding()]
param(
    [ValidateRange(0, 9)]
    [int] $Phase = 0,
    [string] $ReportPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$inventoryPath = Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G03/G03-contract-event-inventory.json'
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = "docs/architecture/review/evidence/gates/G03/G03-phase$Phase-guard-report.json"
}
$resolvedReportPath = if ([System.IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $repositoryRoot $ReportPath }
$generator = Join-Path $PSScriptRoot 'Invoke-G03ContractEventInventory.ps1'

if ($Phase -eq 0) {
    & $generator -ReportPath $inventoryPath
    $firstHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryPath).Hash.ToLowerInvariant()
    & $generator -ReportPath $inventoryPath
    $secondHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryPath).Hash.ToLowerInvariant()
} else {
    $firstHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryPath).Hash.ToLowerInvariant()
    $secondHash = $firstHash
}
$inventory = Get-Content -Raw -LiteralPath $inventoryPath | ConvertFrom-Json -Depth 100
$catalogReportPath = Join-Path $repositoryRoot "docs/architecture/review/evidence/gates/G03/G03-phase$Phase-catalog-report.json"
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
    foreach ($surface in @($inventory.publicSurface)) {
        $sourceKeys += "$($surface.project)|$($surface.name)|"
        foreach ($method in @($surface.methods)) { $sourceKeys += "$($surface.project)|$($surface.name)|$($method.name)" }
    }
    $catalogKeys = @($catalog.publicSurface | ForEach-Object { "$($_.project)|$($_.type)|$($_.member)" })
    $missingCatalogSurface = @($sourceKeys | Where-Object { $_ -notin $catalogKeys } | Sort-Object -Unique)
    $unknownCatalogSurface = @($catalogKeys | Where-Object { $_ -notin $sourceKeys } | Sort-Object -Unique)
    $surfaceReconciled = $missingCatalogSurface.Count -eq 0 -and $unknownCatalogSurface.Count -eq 0 -and $catalogKeys.Count -eq 46
}

$checks = [ordered]@{
    deterministicInventory = $firstHash -eq $secondHash
    exactAbstractionProjectCount = $inventory.counts.abstractionProjects -eq 4
    exactReaderCount = $inventory.counts.readers -eq 4
    exactReaderMethodCount = $inventory.counts.readerMethods -eq 15
    exactDtoCount = $inventory.counts.dtos -eq 7
    exactIntegrationEventCount = $inventory.counts.integrationEvents -eq 20
    messagingSurfaceInventoried = $inventory.counts.messagingAbstractionTypes -eq 4
    generatedDirectoriesExcluded = @($inventory.publicSurface.declaration.file | Where-Object { $_ -match '(^|/)(bin|obj)/' }).Count -eq 0
    catalogValidation = $catalogPassed
    publicSurfaceReconciliation = $surfaceReconciled
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
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedReportPath -Encoding utf8NoBOM
if ($report.result -ne 'passed') { throw "G03 Phase $Phase guard failed. Report: $resolvedReportPath" }
Write-Host "G03 Phase $Phase guard passed. Report: $resolvedReportPath"
