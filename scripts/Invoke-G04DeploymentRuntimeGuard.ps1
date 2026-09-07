[CmdletBinding()]
param(
    [ValidateRange(0, 12)]
    [int] $Phase = 0,
    [string] $ReportPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = "docs/architecture/review/evidence/gates/G04/G04-phase$Phase-guard-report.json"
}
$resolvedReportPath = if ([System.IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $repositoryRoot $ReportPath }
$inventoryPath = Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G04/G04-runtime-inventory.json'

& (Join-Path $PSScriptRoot 'Invoke-G04DeploymentRuntimeInventory.ps1') -ReportPath $inventoryPath
$firstHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryPath).Hash.ToLowerInvariant()
& (Join-Path $PSScriptRoot 'Invoke-G04DeploymentRuntimeInventory.ps1') -ReportPath $inventoryPath
$secondHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryPath).Hash.ToLowerInvariant()
$inventory = Get-Content -Raw -LiteralPath $inventoryPath | ConvertFrom-Json -Depth 100

$checks = [ordered]@{
    deterministicInventory = $firstHash -eq $secondHash
    fiveRequiredBusinessModules = $inventory.businessBoundary.moduleCount -eq 5
    deployableInventoryComplete = @($inventory.deploymentUnits).Count -eq 8
    currentHangfireCouplingRecorded = $inventory.hostedRuntime.hangfireServerImplicit
    currentProbeConflationRecorded = $inventory.probes.aggregateAndReadyEquivalent
    currentOrchestrationRecorded = $inventory.orchestration.initBeforeMigrator -and $inventory.orchestration.migratorBeforeApi
    knownTargetGapsNotMisrepresented = @($inventory.knownGaps).Count -ge 6
    phaseBaselineExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G04/G04-phase0-baseline.md')
}

$report = [ordered]@{
    formatVersion = 1
    gate = 'G04'
    phase = $Phase
    result = if ($checks.Values -contains $false) { 'failed' } else { 'passed' }
    checks = $checks
    sha256 = [ordered]@{ inventory = $secondHash }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedReportPath -Encoding utf8NoBOM
if ($report.result -ne 'passed') { throw "G04 Phase $Phase guard failed. Report: $resolvedReportPath" }
Write-Host "G04 Phase $Phase guard passed. Report: $resolvedReportPath"
