[CmdletBinding()]
param(
    [string] $StatusPath = 'docs/architecture/review/evidence/plan04/phase7-reconciliation-status.json',
    [string] $LayerGuardReportPath = 'docs/architecture/review/evidence/plan04/P04-S7-layerguard-report.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
function Repo([string] $path) { if ([IO.Path]::IsPathRooted($path)) { return $path }; Join-Path $repositoryRoot $path }
function ReadJson([string] $path) { Get-Content -Raw -LiteralPath (Repo $path) | ConvertFrom-Json -Depth 100 }

$governancePassed = $false; $governanceError = $null
try { & (Join-Path $PSScriptRoot 'Test-Plan04Governance.ps1'); $governancePassed = $true } catch { $governanceError = $_.Exception.Message }

$layerGuardPassed = $false; $layerGuardError = $null
try { & (Join-Path $PSScriptRoot 'Invoke-LayerGuard.ps1') -ReportPath $LayerGuardReportPath; $layerGuardPassed = $true } catch { $layerGuardError = $_.Exception.Message }

$buildOutput = @(& dotnet build (Repo 'IFX.sln') --no-restore 2>&1)
$buildExitCode = $LASTEXITCODE
$buildOutput | ForEach-Object { Write-Host $_ }

$testRunDirectory = Repo ("artifacts/plan04-s7-tests/" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRunDirectory -Force | Out-Null
$testOutput = @(& dotnet test (Repo 'IFX.sln') --no-build --no-restore --logger 'trx;LogFilePrefix=plan04-s7-solution' --results-directory $testRunDirectory 2>&1)
$testExitCode = $LASTEXITCODE
$testOutput | ForEach-Object { Write-Host $_ }

$testAssemblies = @()
foreach ($file in @(Get-ChildItem -LiteralPath $testRunDirectory -Filter '*.trx' -File)) {
    [xml]$trx = Get-Content -Raw -LiteralPath $file.FullName
    $counters = $trx.TestRun.ResultSummary.Counters
    $testAssemblies += [pscustomobject][ordered]@{
        name = [IO.Path]::GetFileNameWithoutExtension([string]$trx.TestRun.TestDefinitions.UnitTest[0].TestMethod.codeBase)
        total = [int]$counters.total; passed = [int]$counters.passed; failed = [int]$counters.failed; notExecuted = [int]$counters.notExecuted
    }
}
$testTotals = [ordered]@{
    assemblies = $testAssemblies.Count
    total = [int](($testAssemblies | Measure-Object total -Sum).Sum)
    passed = [int](($testAssemblies | Measure-Object passed -Sum).Sum)
    failed = [int](($testAssemblies | Measure-Object failed -Sum).Sum)
    notExecuted = [int](($testAssemblies | Measure-Object notExecuted -Sum).Sum)
}

$layerGuard = if (Test-Path -LiteralPath (Repo $LayerGuardReportPath)) { ReadJson $LayerGuardReportPath } else { $null }
$handbackPaths = @(
    'docs/architecture/review/evidence/gates/G02/G02-plan04-handback.json',
    'docs/architecture/review/evidence/gates/G03/G03-plan04-handback.json',
    'docs/architecture/review/evidence/gates/G04/G04-plan04-handback.json',
    'docs/architecture/review/evidence/gates/G05/G05-plan04-handback.json'
)
$handbackResults = @($handbackPaths | ForEach-Object {
    $exists = Test-Path -LiteralPath (Repo $_) -PathType Leaf
    $document = if ($exists) { ReadJson $_ } else { $null }
    [ordered]@{ path = $_; exists = $exists; gateClosureUnchanged = $exists -and $document.gateClosureChanged -eq $false }
})
$phase2 = ReadJson 'docs/architecture/review/evidence/plan04/phase2-audit-status.json'
$phase3 = ReadJson 'docs/architecture/review/evidence/plan04/phase3-extraction-policy-status.json'
$phase4 = ReadJson 'docs/architecture/review/evidence/plan04/phase4-tenant-query-status.json'
$phase5 = ReadJson 'docs/architecture/review/evidence/plan04/phase5-projection-status.json'
$checks = [ordered]@{
    unifiedGovernancePassed = $governancePassed
    allModuleBoundaryConclusionsRecorded = @($phase2.conclusions).Count -eq 5 -and @($phase2.conclusions | Where-Object conclusion -eq 'revisit-boundary').Count -eq 0
    modularMonolithRemainsDefault = $phase3.currentModuleDecision -eq 'no-module-approved-for-extraction' -and $phase3.dp8Dp9 -eq 'not-triggered'
    tenantQueryReconciliationPassed = $phase4.result -eq 'repository-passed-production-rls-not-claimed' -and $phase4.metrics.findings -eq 0
    projectionReconciliationPassed = $phase5.result -eq 'repository-passed-no-reporting-product-claimed' -and $phase5.metrics.forbiddenEdges -eq 0 -and $phase5.metrics.crossDbContextFiles -eq 0
    layerGuardPassed = $layerGuardPassed -and $layerGuard.verdict -eq 'baseline-clean' -and $layerGuard.violationCount -eq 0 -and $layerGuard.scope.projectsInScope -eq 39
    fullSolutionBuildPassed = $buildExitCode -eq 0
    fullSolutionTestsPassed = $testExitCode -eq 0 -and $testTotals.assemblies -gt 0 -and $testTotals.total -gt 0 -and $testTotals.total -eq $testTotals.passed -and $testTotals.failed -eq 0 -and $testTotals.notExecuted -eq 0
    gateHandbacksRecordedWithoutPrematureClosure = @($handbackResults | Where-Object { -not $_.exists -or -not $_.gateClosureUnchanged }).Count -eq 0
    rlsAndProductionRemainUnclaimed = $phase4.rls -eq 'deferred-not-claimed' -and $phase4.productionValidation -eq 'not-run-not-claimed' -and $phase5.productionReportingValidation -eq 'not-run-not-claimed'
}
$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$status = [ordered]@{
    formatVersion = 1; plan = '04-module-boundary-evolution'; slice = 'P04-S7'; checkedAt = (Get-Date).ToString('yyyy-MM-dd')
    result = if ($failed.Count -eq 0) { 'repository-passed-functional-approvals-pending' } else { 'failed' }
    checks = $checks
    build = [ordered]@{ command = 'dotnet build IFX.sln --no-restore'; exitCode = $buildExitCode; warningCount = @($buildOutput | Where-Object { $_ -match ': warning ' }).Count; errorCount = @($buildOutput | Where-Object { $_ -match ': error ' }).Count }
    tests = [ordered]@{ command = 'dotnet test IFX.sln --no-build --no-restore'; exitCode = $testExitCode; totals = $testTotals; assemblies = @($testAssemblies | Sort-Object name) }
    layerGuard = [ordered]@{ report = $LayerGuardReportPath; verdict = $layerGuard.verdict; projectsInScope = $layerGuard.scope.projectsInScope; violations = $layerGuard.violationCount }
    gateHandbacks = $handbackResults
    approvals = [ordered]@{ GOV4 = $phase2.gov4; DP6 = if ($phase3.approvalComplete) { 'approved' } else { 'approval-pending' }; planClosure = 'PRE-READY' }
    claims = [ordered]@{ productionRls = 'not-claimed'; productionReporting = 'not-claimed'; productionSlo = 'not-claimed'; microserviceExtraction = 'not-claimed' }
    diagnostics = [ordered]@{ governanceError = $governanceError; layerGuardError = $layerGuardError; packageWarningsRemain = @('NU1603 AWSSDK.CognitoIdentityProvider version resolution','NU1903 AutoMapper advisory','NU1903 Microsoft.Extensions.Caching.Memory advisory') }
    failedChecks = $failed
}
$resolvedStatus = Repo $StatusPath
$status | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $resolvedStatus -Encoding utf8NoBOM
if ($failed.Count -gt 0) { throw "Plan 04 Phase 7 verification failed: $($failed -join ', '). Report: $resolvedStatus" }
Write-Host "Plan 04 Phase 7 result: $($status.result); $($testTotals.passed)/$($testTotals.total) tests passed. Report: $resolvedStatus"
