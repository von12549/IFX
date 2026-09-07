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

if ($Phase -eq 0) {
    & (Join-Path $PSScriptRoot 'Invoke-G04DeploymentRuntimeInventory.ps1') -ReportPath $inventoryPath
    $firstHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryPath).Hash.ToLowerInvariant()
    & (Join-Path $PSScriptRoot 'Invoke-G04DeploymentRuntimeInventory.ps1') -ReportPath $inventoryPath
    $secondHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryPath).Hash.ToLowerInvariant()
} else {
    $firstHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryPath).Hash.ToLowerInvariant()
    $secondHash = $firstHash
}
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

if ($Phase -ge 1) {
    $manifestReportPath = Join-Path $repositoryRoot "docs/architecture/review/evidence/gates/G04/G04-phase$Phase-manifest-report.json"
    & (Join-Path $PSScriptRoot 'Test-G04Manifests.ps1') -ReportPath "docs/architecture/review/evidence/gates/G04/G04-phase$Phase-manifest-report.json"
    $manifestReport = Get-Content -Raw -LiteralPath $manifestReportPath | ConvertFrom-Json -Depth 100
    $checks.manifestValidation = $manifestReport.result -eq 'passed'
}

if ($Phase -ge 2) {
    $program = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/Program.cs')
    $backgroundJobs = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/Platform/BackgroundJobs/IFX.Platform.BackgroundJobs.Composition/BackgroundJobsServiceCollectionExtensions.cs')
    $compose = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docker-compose.yml')
    $checks.runtimeProfileResolverExists = Test-Path (Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/Runtime/RuntimeProfileResolver.cs')
    $checks.apiEndpointMappingIsRoleGated = $program -match 'if \(runtimeProfile\.Capabilities\.Api\)[\s\S]*?installer\.MapEndpoints'
    $checks.hangfireClientServerSplit = ($backgroundJobs -match 'AddBackgroundJobsClient') -and ($backgroundJobs -match 'AddBackgroundJobsServer')
    $checks.hangfireServerIsRoleGated = $program -match 'if \(runtimeProfile\.Capabilities\.HangfireServer\)[\s\S]*?AddBackgroundJobsServer'
    $checks.sameArtifactApiWorkerCompose = ($compose -match 'ifx-api:[\s\S]*?dockerfile: src/ApiHost/IFX.ApiHost/Dockerfile') -and ($compose -match 'ifx-worker:[\s\S]*?dockerfile: src/ApiHost/IFX.ApiHost/Dockerfile')
    $checks.workerRoleConfigured = $compose -match 'ifx-worker:[\s\S]*?Runtime__Role=worker'
}

if ($Phase -ge 3) {
    $program = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/Program.cs')
    $monitor = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/Runtime/StartupDependencyMonitor.cs')
    $checks.manifestsLoadedBeforeBuild = $program.IndexOf('RuntimeManifestLoader.Load', [StringComparison]::Ordinal) -lt $program.IndexOf('builder.Build()', [StringComparison]::Ordinal)
    $checks.platformRegisteredBeforeModules = $program.IndexOf('builder.Services.AddMessaging()', [StringComparison]::Ordinal) -lt $program.IndexOf('builder.Services.AddAuthModule', [StringComparison]::Ordinal)
    $checks.manifestOrdersEndpointMapping = $program -match 'orderedInstallers[\s\S]*?installer\.MapEndpoints'
    $checks.compositionValidatedAfterBuild = $program -match 'builder\.Build\(\)[\s\S]*?StartupBoundaryVerifier\.ValidateComposition'
    $checks.endpointCollisionValidated = $program -match 'StartupBoundaryVerifier\.ValidateEndpointIdentity'
    $checks.recoverableDependenciesAsync = ($monitor -match 'BackgroundService') -and ($monitor -match 'while \(!stoppingToken\.IsCancellationRequested\)')
    $checks.readinessChecksBounded = ($monitor -match 'CancelAfter\(timeout\)') -and ($monitor -match 'readiness-critical')
    $checks.dependencyReviewExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G04/G04-phase3-dependency-review.md')
}

if ($Phase -ge 4) {
    $program = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/Program.cs')
    $backgroundJobs = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/Platform/BackgroundJobs/IFX.Platform.BackgroundJobs.Composition/BackgroundJobsServiceCollectionExtensions.cs')
    $compose = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docker-compose.yml')
    $checks.perModuleDispatcherContractExists = Test-Path (Join-Path $repositoryRoot 'src/Platform/Messaging/IFX.Platform.Messaging.Composition/Dispatching/DispatcherRuntimeContracts.cs')
    $checks.sqlLeaseReferenceSuiteExists = Test-Path (Join-Path $repositoryRoot 'tests/IFX.DatabaseBoundary.Tests/G04DispatcherLeaseConformanceTests.cs')
    $checks.uniqueRuntimeIdentityCreated = $program -match 'RuntimeInstanceIdentity\.Create'
    $checks.runtimeIdentityOverridesHangfire = ($program -match 'AddBackgroundJobsServer\(builder\.Configuration, runtimeInstanceIdentity\.Value\)') -and ($backgroundJobs -match 'options\.ServerName = runtimeInstanceIdentity')
    $checks.fixedHangfireIdentityRemoved = $compose -notmatch 'auth-api-worker'
    $checks.criticalLoopTerminatesNonZero = (Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/Runtime/CriticalWorkerBackgroundService.cs')) -match 'Environment\.ExitCode = 1'
    $checks.leaseConformanceDocumented = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G04/G04-phase4-lease-conformance.md')
}

if ($Phase -ge 5) {
    $program = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/Program.cs')
    $drainCoordinator = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/Runtime/RuntimeDrainCoordinator.cs')
    $drainOptions = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/Runtime/RuntimeDrainOptions.cs')
    $compose = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docker-compose.yml')
    $checks.sharedDrainSignalRegistered = ($program -match 'RuntimeDrainCoordinator') -and ($program -match 'IRuntimeDrainSignal')
    $checks.newWorkRejectedAtomically = ($drainCoordinator -match 'TryBeginOperation') -and ($drainCoordinator -match 'Interlocked\.Exchange\(ref _draining')
    $checks.inFlightDrainBounded = ($drainCoordinator -match 'WaitForIdleAsync') -and ($drainCoordinator -match 'CancelAfter\(timeout\)')
    $checks.strictDrainBudgetsValidated = ($drainOptions -match 'OperationBudget') -and
        ($drainOptions -match 'HandlerBudget') -and
        ($drainOptions -match 'LeaseBudget') -and
        ($drainOptions -match 'ProcessGrace') -and
        ($drainOptions -match 'OrchestratorKill')
    $checks.composeUsesBoundedSigterm = ($compose -match 'stop_signal: SIGTERM') -and ($compose -match 'stop_grace_period: 45s')
    $checks.phase5EvidenceExists = Test-Path (Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G04/G04-phase5-drain-conformance.md')
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
