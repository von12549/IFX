[CmdletBinding()]
param(
    [string] $ClosureEvidencePath = 'deployment/plan02/release-closure-evidence-template.json',
    [string] $ReleaseEvidencePath = 'deployment/g04/release-evidence-template.json',
    [string] $AlertEvidencePath = 'deployment/plan02/messaging-alert-calibration-evidence-template.json',
    [string] $FullPathEvidencePath = 'deployment/plan02/full-path-validation-evidence-template.json',
    [string] $ReportPath = 'docs/architecture/review/evidence/plan02/P02-C5-validation.json',
    [switch] $RequireTargetEvidence
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
function Repo([string] $path) {
    if ([IO.Path]::IsPathRooted($path)) { return $path }
    return Join-Path $repositoryRoot $path
}
function Resolved([object] $value) {
    return $null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value) -and [string]$value -notmatch '<[^>]+>'
}
function Timestamp([object] $value) {
    if (-not (Resolved $value)) { return $null }
    $parsed = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse([string]$value, [ref]$parsed)) { return $null }
    return $parsed
}
function Sha256([string] $path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath (Repo $path)).Hash.ToLowerInvariant()
}

$closureText = Get-Content -Raw -LiteralPath (Repo $ClosureEvidencePath)
$closure = $closureText | ConvertFrom-Json -Depth 100
$release = Get-Content -Raw -LiteralPath (Repo $ReleaseEvidencePath) | ConvertFrom-Json -Depth 100
$alert = Get-Content -Raw -LiteralPath (Repo $AlertEvidencePath) | ConvertFrom-Json -Depth 100
$fullPath = Get-Content -Raw -LiteralPath (Repo $FullPathEvidencePath) | ConvertFrom-Json -Depth 100
$orchestration = Get-Content -Raw -LiteralPath (Repo 'deployment/g04/release-orchestration.json') | ConvertFrom-Json -Depth 100
$runtimeProfile = Get-Content -Raw -LiteralPath (Repo 'src/ApiHost/IFX.ApiHost/Runtime/RuntimeProfileResolver.cs')
$runtimeTests = Get-Content -Raw -LiteralPath (Repo 'tests/IFX.IntegrationTests/Runtime/RuntimeProfileResolverTests.cs')
$messagingRegistration = Get-Content -Raw -LiteralPath (Repo 'src/Platform/Messaging/IFX.Platform.Messaging.Runtime/MessagingServiceCollectionExtensions.cs')
$dispatcher = Get-Content -Raw -LiteralPath (Repo 'src/Platform/Messaging/IFX.Platform.Messaging.Runtime/OutboxDispatcherHostedService.cs')
$receiver = Get-Content -Raw -LiteralPath (Repo 'src/Platform/Messaging/IFX.Platform.Messaging.Runtime/RawIntegrationEventReceiver.cs')
$holdingsRegistration = Get-Content -Raw -LiteralPath (Repo 'src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure/DependencyInjection.cs')
$producerApplicationText = @(
    'src/Modules/Registry/IFX.Modules.Registry.Application',
    'src/Modules/Transaction/IFX.Modules.Transaction.Application'
) | ForEach-Object {
    Get-ChildItem -LiteralPath (Repo $_) -Recurse -Filter '*.cs' | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }
}
$producerInfrastructureText = @(
    'src/Modules/Registry/IFX.Modules.Registry.Infrastructure/Messaging/RegistryOutboxParticipant.cs',
    'src/Modules/Transaction/IFX.Modules.Transaction.Infrastructure/Messaging/TransactionOutboxParticipant.cs'
) | ForEach-Object { Get-Content -Raw -LiteralPath (Repo $_) }
$plan = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/02-reliable-integration-events.md')
$runbook = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/runbooks/plan02-reliable-events.md')
$readiness = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/evidence/final-closure/readiness.json') | ConvertFrom-Json -Depth 100
$sourceFiles = Get-ChildItem -LiteralPath (Repo 'src') -Recurse -Filter '*.cs'
$senderUsers = @($sourceFiles | Where-Object {
    (Get-Content -Raw -LiteralPath $_.FullName) -match '\bIIntegrationEventSender\b'
} | ForEach-Object { [IO.Path]::GetRelativePath($repositoryRoot, $_.FullName).Replace('\', '/') } | Sort-Object)
$expectedSenderUsers = @(
    'src/Platform/Messaging/IFX.Platform.Messaging.Runtime/InProcessIntegrationEventTransport.cs',
    'src/Platform/Messaging/IFX.Platform.Messaging.Runtime/MessagingServiceCollectionExtensions.cs',
    'src/Platform/Messaging/IFX.Platform.Messaging.Runtime/OutboxDispatcherHostedService.cs',
    'src/Platform/Messaging/IFX.Platform.Messaging.Runtime/RuntimeContracts.cs'
) | Sort-Object
$inboundHandlerUsers = @($sourceFiles | Where-Object {
    (Get-Content -Raw -LiteralPath $_.FullName) -match '\bIInboundIntegrationEventHandler\b'
} | ForEach-Object { [IO.Path]::GetRelativePath($repositoryRoot, $_.FullName).Replace('\', '/') } | Sort-Object)
$expectedInboundHandlerUsers = @(
    'src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure/DependencyInjection.cs',
    'src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure/Messaging/HoldingsInboundIntegrationEventHandler.cs',
    'src/Platform/Messaging/IFX.Platform.Messaging.Runtime/RawIntegrationEventReceiver.cs',
    'src/Platform/Messaging/IFX.Platform.Messaging.Runtime/RuntimeContracts.cs'
) | Sort-Object

$expectedStages = @('database-preflight','restore-point','database-migrator','schema-validation','worker-consumer','api-producer','scheduler','observation','contract-cleanup')
$stageIds = @($orchestration.stages.stageId)
$stageIndex = @{}
for ($i = 0; $i -lt $stageIds.Count; $i++) { $stageIndex[$stageIds[$i]] = $i }
$repoChecks = [ordered]@{
    exactConsumerFirstOrchestration = ($stageIds -join ',') -eq ($expectedStages -join ',') -and
        $stageIndex['worker-consumer'] -lt $stageIndex['api-producer'] -and
        $stageIndex['observation'] -lt $stageIndex['contract-cleanup']
    cleanupDependsOnObservationAndZeroDemand = 'observation' -in @($orchestration.stages | Where-Object stageId -eq 'contract-cleanup').requires -and
        ($orchestration.stages | Where-Object stageId -eq 'contract-cleanup').successEvidence -match 'zero old-version demand'
    apiWorkerRolesFailClosed = $runtimeProfile -match 'RuntimeRole\.Api => new RuntimeCapabilities\(true, true, false, false, false, false\)' -and
        $runtimeProfile -match 'G04-RUNTIME-API-CAPABILITY-MISMATCH' -and
        $runtimeTests -match 'Resolve_ApiWithWorkerExecution_FailsWithStableReason' -and
        $runtimeTests -match 'Resolve_ProductionAllWithoutApproval_FailsWithStableReason'
    producerUsesTransactionalBufferOnly = ($producerApplicationText -join "`n") -match '\bICommittedEventBuffer\b' -and
        ($producerApplicationText -join "`n") -notmatch '\bIIntegrationEventSender\b|\bIInboundIntegrationEventHandler\b' -and
        ($producerInfrastructureText -join "`n") -match '\bIPendingIntegrationEventSource\b' -and
        ($producerInfrastructureText -join "`n") -match '\.Drain\(\)'
    dispatcherIsOnlyTransportSendPath = $messagingRegistration -match 'AddSingleton<IIntegrationEventSender, InProcessIntegrationEventTransport>' -and
        $dispatcher -match 'await transport\.SendAsync\(lease\.Message' -and
        $dispatcher -match 'await store\.CompleteAsync\(lease' -and
        @(Compare-Object $expectedSenderUsers $senderUsers).Count -eq 0
    inboundResolutionIsAdapterMediated = $receiver -match 'GetServices<IInboundIntegrationEventHandler>' -and
        $receiver -match 'await handler\.HandleAsync\(decoded\.Message' -and
        $holdingsRegistration -match 'AddScoped<IFX\.Platform\.Messaging\.Runtime\.IInboundIntegrationEventHandler, HoldingsInboundIntegrationEventHandler>' -and
        @(Compare-Object $expectedInboundHandlerUsers $inboundHandlerUsers).Count -eq 0
    checklistRemainsTruthfullyOpen = $plan -match '- \[ \] E7\.5' -and $plan -match '- \[ \] E7\.6' -and
        $plan -match '- \[ \] \*\*Phase 7 完成'
    runbookBindsP02C5StrictGate = $runbook -match 'release-closure-evidence-template\.json' -and
        $runbook -match 'Test-Plan02C5ReleaseClosure\.ps1' -and
        $runbook -match '旧路径关闭不得早于观测窗口完成'
    readinessTracksP02C5Pending = 'E7.5' -in @($readiness.plan02.openChecklistItems) -and
        'E7.6' -in @($readiness.plan02.openChecklistItems) -and
        @($readiness.plan02.inProgressSlices | Where-Object { $_ -match '^P02-C5/' }).Count -eq 1
}

$releaseStarted = @{}
$releaseCompleted = @{}
$releaseStagesValid = ($release.stages.stageId -join ',') -eq ($expectedStages -join ',')
$previousCompletion = [DateTimeOffset]::MinValue
foreach ($stage in @($release.stages)) {
    $started = Timestamp $stage.startedAt
    $completed = Timestamp $stage.completedAt
    if ($stage.status -ne 'succeeded' -or -not (Resolved $stage.evidence) -or $null -eq $started -or $null -eq $completed -or
        $started -lt $previousCompletion -or $completed -lt $started) {
        $releaseStagesValid = $false
    }
    if ($null -ne $started) { $releaseStarted[$stage.stageId] = $started }
    if ($null -ne $completed) { $releaseCompleted[$stage.stageId] = $completed; $previousCompletion = $completed }
}

$observationStarted = Timestamp $closure.observationWindow.startedAt
$observationCompleted = Timestamp $closure.observationWindow.completedAt
$cleanupStarted = Timestamp $closure.cleanup.startedAt
$cleanupCompleted = Timestamp $closure.cleanup.completedAt
$capturedAt = Timestamp $closure.capturedAt
$requiredExercises = @('rolling-consumer-first','sigterm-drain','forced-termination','backpressure-recovery','network-policy','total-capacity','safe-rollback','roll-forward')
$targetChecks = [ordered]@{
    completedTargetIdentity = $closure.formatVersion -eq 1 -and $closure.controlSet -eq 'P02-C5-E7.5-E7.6' -and
        $closure.status -eq 'completed' -and (Resolved $closure.releaseId) -and (Resolved $closure.environment) -and
        [string]$closure.artifactDigest -match '^sha256:[0-9a-f]{64}$'
    noTemplatePlaceholdersRemain = $closureText -notmatch '<[^>]+>'
    prerequisiteEvidenceCompletedAndBound = $alert.status -eq 'completed' -and $fullPath.status -eq 'completed' -and
        $closure.alertCalibrationEvidenceSha256 -eq (Sha256 $AlertEvidencePath) -and
        $closure.fullPathEvidenceSha256 -eq (Sha256 $FullPathEvidencePath) -and
        $alert.releaseId -eq $closure.releaseId -and $alert.environment -eq $closure.environment -and
        $fullPath.releaseId -eq $closure.releaseId -and $fullPath.environment -eq $closure.environment
    g04ReleaseCompletedAndBound = $release.status -eq 'completed' -and $releaseStagesValid -and
        $closure.g04ReleaseEvidenceSha256 -eq (Sha256 $ReleaseEvidencePath) -and
        $release.releaseId -eq $closure.releaseId -and $release.environment -eq $closure.environment -and
        $release.artifactDigest -eq $closure.artifactDigest
    workerActuallyPrecededApi = $releaseCompleted.ContainsKey('worker-consumer') -and $releaseStarted.ContainsKey('api-producer') -and
        $releaseCompleted['worker-consumer'] -le $releaseStarted['api-producer']
    authoritativePathAndSingletonVerified = $closure.authoritativePath.producerPath -eq 'module-business-transaction-to-module-outbox' -and
        $closure.authoritativePath.dispatchPath -eq 'worker-outbox-dispatcher-to-approved-transport' -and
        $closure.authoritativePath.inboundPath -eq 'raw-receiver-to-inbox-and-consumer-transaction' -and
        $closure.authoritativePath.schedulerAuthorityCount -eq 1 -and
        $closure.authoritativePath.legacySynchronousSenderRegistrations -eq 0 -and
        $closure.authoritativePath.legacyDirectHandlerRegistrations -eq 0 -and
        $closure.authoritativePath.legacyPathTrafficCount -eq 0 -and
        (Resolved $closure.authoritativePath.inventoryReference) -and (Resolved $closure.authoritativePath.runtimeVerificationReference)
    observationThresholdsAndZeroDemandAccepted = $null -ne $observationStarted -and $null -ne $observationCompleted -and
        $observationStarted -le $observationCompleted -and $closure.observationWindow.minimumDurationMinutes -gt 0 -and
        $closure.observationWindow.actualDurationMinutes -ge $closure.observationWindow.minimumDurationMinutes -and
        $closure.observationWindow.acceptedCalibratedThresholds -eq $true -and $closure.observationWindow.backlogStable -eq $true -and
        $closure.observationWindow.retryRateStable -eq $true -and $closure.observationWindow.deadLetterGrowthStable -eq $true -and
        $closure.observationWindow.duplicateBusinessEffectCount -eq 0 -and $closure.observationWindow.dataLossDetected -eq $false -and
        $closure.observationWindow.oldConsumerDemandCount -eq 0 -and $closure.observationWindow.oldApiDemandCount -eq 0 -and
        $closure.observationWindow.oldSchemaDemandCount -eq 0 -and (Resolved $closure.observationWindow.metricsReference) -and
        (Resolved $closure.observationWindow.demandAnalysisReference)
    rehearsalExerciseMatrixComplete = @(Compare-Object $requiredExercises @($closure.rehearsalExercises.id)).Count -eq 0 -and
        @($closure.rehearsalExercises | Where-Object { $_.passed -ne $true -or -not (Resolved $_.evidenceReference) }).Count -eq 0
    cleanupOnlyAfterObservation = $closure.cleanup.performed -eq $true -and $null -ne $cleanupStarted -and $null -ne $cleanupCompleted -and
        $null -ne $observationCompleted -and $cleanupStarted -ge $observationCompleted -and $cleanupCompleted -ge $cleanupStarted -and
        $closure.cleanup.legacyCodeRemoved -eq $true -and $closure.cleanup.legacyRegistrationsRemoved -eq $true -and
        $closure.cleanup.legacyConfigurationRemoved -eq $true -and $closure.cleanup.postCleanupSmokePassed -eq $true -and
        (Resolved $closure.cleanup.changeReference) -and (Resolved $closure.cleanup.verificationReference)
    namedApprovalsAndCaptureComplete = @('architecture','producerModuleOwner','consumerModuleOwner','platformMessaging','platformOperations','database','security','releaseOperations' |
        Where-Object { -not (Resolved $closure.approvals.$_) }).Count -eq 0 -and $null -ne $capturedAt -and
        $null -ne $cleanupCompleted -and $capturedAt -ge $cleanupCompleted
}

$failedRepositoryChecks = @($repoChecks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$failedTargetChecks = @($targetChecks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$repositoryPassed = $failedRepositoryChecks.Count -eq 0
$targetPassed = $failedTargetChecks.Count -eq 0
$result = if (-not $repositoryPassed) { 'failed' } elseif ($targetPassed) { 'passed' } else { 'repository-passed-release-rehearsal-pending' }
$report = [ordered]@{
    formatVersion = 1
    plan = '02-reliable-integration-events'
    slice = 'P02-C5'
    result = $result
    e7_5 = [ordered]@{ result = if ($targetPassed) { 'passed' } else { 'target-consumer-first-rehearsal-pending' }; checklistMayClose = $targetPassed }
    e7_6 = [ordered]@{ result = if ($targetPassed) { 'passed' } else { 'observation-and-old-path-cleanup-pending' }; checklistMayClose = $targetPassed }
    phase7MayClose = $targetPassed -and $fullPath.status -eq 'completed'
    repositoryChecks = $repoChecks
    targetChecks = $targetChecks
    failedRepositoryChecks = $failedRepositoryChecks
    failedTargetChecks = $failedTargetChecks
    nextAction = if ($targetPassed) {
        'Close E7.5 and E7.6; close Phase 7 only when P02-C4 E7.3, E7.4 and E7.8 are also recorded closed.'
    } else {
        'After a production platform is selected, complete P02-C3 and P02-C4 target evidence, run the G04 nine-stage consumer-first rehearsal, observe zero old-version demand, then remove old paths and rerun with -RequireTargetEvidence.'
    }
}
$resolvedReport = Repo $ReportPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReport) | Out-Null
$report | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $resolvedReport -Encoding utf8NoBOM

if (-not $repositoryPassed) {
    throw "Plan 02 P02-C5 repository validation failed: $($failedRepositoryChecks -join ', '). Report: $resolvedReport"
}
if ($RequireTargetEvidence -and -not $targetPassed) {
    throw "Plan 02 P02-C5 target evidence is incomplete: $($failedTargetChecks -join ', '). Report: $resolvedReport"
}
Write-Host "Plan 02 P02-C5 validation result: $result. Report: $resolvedReport"
