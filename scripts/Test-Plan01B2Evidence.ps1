[CmdletBinding()]
param(
    [string] $LayerGuardReportPath = 'docs/architecture/review/evidence/layerguard/B2-report.json',
    [string] $StatusPath = 'docs/architecture/review/evidence/plan01/B2-validation-status.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
function Resolve-RepoPath([string] $path) {
    if ([IO.Path]::IsPathRooted($path)) { return $path }
    return Join-Path $repositoryRoot $path
}
function Read-Json([string] $path) {
    $resolved = Resolve-RepoPath $path
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "Required B2 artifact is missing: $resolved" }
    Get-Content -Raw -LiteralPath $resolved | ConvertFrom-Json -Depth 100
}

$report = Read-Json $LayerGuardReportPath
$comparison = Read-Json 'docs/architecture/review/evidence/layerguard/B2-vs-B1-report.json'
$baseline = Read-Json 'mcp/LayerGuard/baselines/b2.json'
$catalog = Read-Json 'docs/architecture/review/gates/G03/contract-event-catalog.yaml'
$g03 = Read-Json 'docs/architecture/review/evidence/gates/G03/G03-B2-guard-report.json'
$config = Read-Json 'src/layerguard.json'
$transactionApplication = Get-ChildItem (Resolve-RepoPath 'src/Modules/Transaction/IFX.Modules.Transaction.Application') -Recurse -File -Filter '*.cs' |
    ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }
$checks = [ordered]@{
    currentBaselineClean = $report.verdict -eq 'baseline-clean' -and $report.baseline.matched -eq 103 -and $report.baseline.new -eq 0 -and $report.baseline.stale -eq 0
    b1Improvement = $comparison.baseline.matched -eq 103 -and $comparison.baseline.new -eq 0 -and $comparison.baseline.stale -eq 13
    baselineFrozen = @($baseline.entries).Count -eq 103 -and $baseline.rulesetHash -eq $report.ruleset.hash
    activeSyncContracts = @($catalog.protocols | Where-Object { $_.kind -eq 'sync' -and $_.lifecycle -eq 'Active' }).Count -eq 2
    eventsRemainOpen = @($catalog.protocols | Where-Object { $_.kind -eq 'event' -and $_.lifecycle -eq 'Proposed' }).Count -eq 2
    legacySurfaceDisposition = @($catalog.publicSurface | Where-Object lifecycle -eq 'Retired').Count -eq 26 -and @($catalog.publicSurface | Where-Object lifecycle -eq 'LegacyPendingMigration').Count -eq 20
    applicationIsolation = @($transactionApplication | Where-Object { $_ -match 'IFX\.Modules\.(CRM|Registry)\.(Contracts|Abstractions)' }).Count -eq 0
    g03Handback = $g03.result -eq 'passed'
    noCopiedGateAuthority = $config.PSObject.Properties.Name -notcontains 'providerContracts'
    visualEvidence = (Test-Path (Resolve-RepoPath 'docs/architecture/review/diagrams/plan01-contract-boundary.svg')) -and (Test-Path (Resolve-RepoPath 'docs/architecture/review/diagrams/plan01-contract-boundary.png'))
}
$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$status = [ordered]@{
    formatVersion = 1; plan = '01-contracts-adapters-refactor'; milestone = 'B2'
    result = if ($failed.Count -eq 0) { 'passed' } else { 'failed' }
    checkedAt = '2026-09-08'; checks = $checks
    metrics = [ordered]@{ findings = $report.violationCount; clusters = @($report.clusters).Count; baselineMatched = $report.baseline.matched; baselineNew = $report.baseline.new; baselineStale = $report.baseline.stale }
    failedChecks = $failed; remainingScope = @('Plan 02', 'B3', 'B4', 'Gate Final Closure')
}
$resolvedStatus = Resolve-RepoPath $StatusPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedStatus) | Out-Null
$status | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedStatus -Encoding utf8NoBOM
if ($failed.Count -gt 0) { throw "Plan 01 B2 validation failed: $($failed -join ', '). Report: $resolvedStatus" }
Write-Host "Plan 01 B2 validation passed: $resolvedStatus"
