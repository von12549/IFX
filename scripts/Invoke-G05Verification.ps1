[CmdletBinding()]
param(
    [string] $OutputDirectory = 'artifacts/g05',
    [switch] $SkipRestore
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $repositoryRoot $OutputDirectory }
$baselinePath = Join-Path $repositoryRoot 'docs/architecture/review/gates/G05/verification-baseline-v1.json'
$solutionPath = Join-Path $repositoryRoot 'IFX.sln'
$testRunDirectory = Join-Path $resolvedOutput (Join-Path 'test-results' ([Guid]::NewGuid().ToString('N')))
New-Item -ItemType Directory -Force -Path $resolvedOutput, $testRunDirectory | Out-Null

function Assert-LastExitCode([string] $message) {
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) { throw "$message Exit code: $LASTEXITCODE." }
}

if (-not $SkipRestore) {
    & dotnet restore $solutionPath
    Assert-LastExitCode 'G05 solution restore failed.'
}

# Migration safety invokes the inventory tool with -NoBuild. Build the solution
# (including IFX.DatabaseInventory) before any consumer assumes its outputs exist.
& dotnet build $solutionPath --no-restore
Assert-LastExitCode 'G05 solution build failed.'

$catalogReportPath = Join-Path $resolvedOutput 'catalog-security.json'
& (Join-Path $PSScriptRoot 'Test-G03ContractEventCatalog.ps1') -ReportPath $catalogReportPath -SelfTest
Assert-LastExitCode 'G05 catalog/security validation failed.'

$relativeMigrationReport = [IO.Path]::GetRelativePath(
    $repositoryRoot,
    (Join-Path $resolvedOutput 'migration-safety.json')).Replace('\', '/')
& (Join-Path $PSScriptRoot 'Test-MigrationSafetyPolicy.ps1') -ReportPath $relativeMigrationReport -NoBuild
Assert-LastExitCode 'G05 migration safety validation failed.'

$layerGuardReportPath = Join-Path $resolvedOutput 'layerguard.json'
& (Join-Path $PSScriptRoot 'Invoke-LayerGuard.ps1') -ReportPath $layerGuardReportPath
Assert-LastExitCode 'G05 LayerGuard validation failed.'

$g05ReportPath = Join-Path $resolvedOutput 'context-boundary.json'
& (Join-Path $PSScriptRoot 'Invoke-G05ContextBoundaryGuard.ps1') -Phase 9 -ReportPath $g05ReportPath
Assert-LastExitCode 'G05 cumulative context-boundary validation failed.'

& dotnet test $solutionPath --no-build --no-restore --results-directory $testRunDirectory --logger 'trx;LogFilePrefix=solution'
Assert-LastExitCode 'G05 solution tests failed.'

$testCounters = [ordered]@{ total = 0; executed = 0; passed = 0; failed = 0; skipped = 0 }
$trxFiles = @(Get-ChildItem -LiteralPath $testRunDirectory -File -Filter '*.trx')
if ($trxFiles.Count -eq 0) { throw 'G05 solution test run produced no TRX evidence.' }
foreach ($trxFile in $trxFiles) {
    [xml] $trx = Get-Content -Raw -LiteralPath $trxFile.FullName
    $counters = $trx.TestRun.ResultSummary.Counters
    $testCounters.total += [int] $counters.total
    $testCounters.executed += [int] $counters.executed
    $testCounters.passed += [int] $counters.passed
    $testCounters.failed += [int] $counters.failed
    $testCounters.skipped += [int] $counters.notExecuted
}

$baseline = Get-Content -Raw -LiteralPath $baselinePath | ConvertFrom-Json -Depth 20
$catalogReport = Get-Content -Raw -LiteralPath $catalogReportPath | ConvertFrom-Json -Depth 100
$migrationReport = Get-Content -Raw -LiteralPath (Join-Path $resolvedOutput 'migration-safety.json') | ConvertFrom-Json -Depth 30
$layerGuardReport = Get-Content -Raw -LiteralPath $layerGuardReportPath | ConvertFrom-Json -Depth 30
$g05Report = Get-Content -Raw -LiteralPath $g05ReportPath | ConvertFrom-Json -Depth 30
$failedSelfTests = @($catalogReport.selfTests | Where-Object passed -ne $true)

$checks = [ordered]@{
    baselineFormat = $baseline.formatVersion -eq 1 -and $baseline.gate -eq 'G05'
    catalog = $catalogReport.result -eq $baseline.requiredResults.catalog
    catalogMutationSelfTests = @($catalogReport.selfTests).Count -eq $baseline.requiredResults.catalogMutationSelfTests -and
        $failedSelfTests.Count -eq 0 -and
        (@($catalogReport.selfTests.name | Sort-Object) -join '|') -eq (@($baseline.requiredCatalogMutationNames | Sort-Object) -join '|')
    migrationSafety = $migrationReport.result -eq $baseline.requiredResults.migrationSafety
    cumulativeG05 = $g05Report.result -eq 'passed' -and $g05Report.phase -eq $baseline.requiredResults.g05GuardPhase
    layerGuard = $layerGuardReport.verdict -eq $baseline.requiredResults.layerGuardVerdict -and $layerGuardReport.baseline.new -eq $baseline.requiredResults.layerGuardNewViolations -and $layerGuardReport.baseline.stale -eq $baseline.requiredResults.layerGuardStaleViolations
    solutionTests = $testCounters.passed -ge $baseline.minimumSolutionTests -and $testCounters.failed -eq $baseline.requiredResults.solutionFailed -and $testCounters.executed -eq $testCounters.passed
}

$summary = [ordered]@{
    formatVersion = 1
    gate = 'G05'
    phase = 9
    result = if ($checks.Values -contains $false) { 'failed' } else { 'passed' }
    scope = 'repository-automation-no-production-claim'
    completedAt = [DateTimeOffset]::UtcNow.ToString('O')
    checks = $checks
    solutionTests = $testCounters
    reports = [ordered]@{
        catalog = [IO.Path]::GetRelativePath($resolvedOutput, $catalogReportPath).Replace('\', '/')
        migrationSafety = 'migration-safety.json'
        contextBoundary = 'context-boundary.json'
        layerGuard = 'layerguard.json'
        trxDirectory = [IO.Path]::GetRelativePath($resolvedOutput, $testRunDirectory).Replace('\', '/')
    }
    sha256 = [ordered]@{
        baseline = (Get-FileHash -Algorithm SHA256 -LiteralPath $baselinePath).Hash.ToLowerInvariant()
        catalog = (Get-FileHash -Algorithm SHA256 -LiteralPath $catalogReportPath).Hash.ToLowerInvariant()
        migrationSafety = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $resolvedOutput 'migration-safety.json')).Hash.ToLowerInvariant()
        contextBoundary = (Get-FileHash -Algorithm SHA256 -LiteralPath $g05ReportPath).Hash.ToLowerInvariant()
        layerGuard = (Get-FileHash -Algorithm SHA256 -LiteralPath $layerGuardReportPath).Hash.ToLowerInvariant()
    }
    truthfulBoundary = $baseline.truthfulBoundary
}

$summaryPath = Join-Path $resolvedOutput 'verification-summary.json'
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding utf8NoBOM
if ($summary.result -ne 'passed') { throw "G05 verification failed. Summary: $summaryPath" }
Write-Host "G05 verification passed: $resolvedOutput"
