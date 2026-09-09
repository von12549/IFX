[CmdletBinding()]
param(
    [string] $DecisionPath = "deployment/plan02/reprocessing-policy.json",
    [string] $AlertEvidencePath = "deployment/plan02/messaging-alert-calibration-evidence-template.json",
    [string] $ReportPath = "docs/architecture/review/evidence/plan02/P02-C3-validation.json",
    [switch] $RequireAlertCalibration
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
function Repo([string] $path) {
    if ([IO.Path]::IsPathRooted($path)) { return $path }
    return Join-Path $repositoryRoot $path
}
function Resolved([object] $value) {
    return $null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value) -and [string]$value -notmatch '<[^>]+>'
}
function AllTrue([object] $object, [string[]] $properties) {
    return @($properties | Where-Object { $object.$_ -ne $true }).Count -eq 0
}
function Timestamp([object] $value) {
    if (-not (Resolved $value)) { return $false }
    $parsed = [DateTimeOffset]::MinValue
    return [DateTimeOffset]::TryParse([string]$value, [ref]$parsed)
}

$decisionPathResolved = Repo $DecisionPath
$alertEvidencePathResolved = Repo $AlertEvidencePath
$backpressurePath = Repo 'deployment/g04/backpressure-policy.json'
$decision = Get-Content -Raw -LiteralPath $decisionPathResolved | ConvertFrom-Json -Depth 100
$alertEvidenceText = Get-Content -Raw -LiteralPath $alertEvidencePathResolved
$alertEvidence = $alertEvidenceText | ConvertFrom-Json -Depth 100
$backpressure = Get-Content -Raw -LiteralPath $backpressurePath | ConvertFrom-Json -Depth 100
$runtimeContracts = Get-Content -Raw -LiteralPath (Repo 'src/Platform/Messaging/IFX.Platform.Messaging.Runtime/RuntimeContracts.cs')
$telemetry = Get-Content -Raw -LiteralPath (Repo 'src/Platform/Messaging/IFX.Platform.Messaging.Runtime/MessagingTelemetry.cs')
$health = Get-Content -Raw -LiteralPath (Repo 'src/Platform/Messaging/IFX.Platform.Messaging.Composition/MessagingHealthProbe.cs')
$operations = Get-Content -Raw -LiteralPath (Repo 'src/Platform/Messaging/IFX.Platform.Messaging.Composition/MessagingOperations.cs')
$endpoints = Get-Content -Raw -LiteralPath (Repo 'src/ApiHost/IFX.ApiHost/Configuration/MessagingOperationsConfiguration.cs')
$stores = (Get-Content -Raw -LiteralPath (Repo 'src/Modules/Registry/IFX.Modules.Registry.Infrastructure/Messaging/RegistryOutboxStore.cs')) +
    (Get-Content -Raw -LiteralPath (Repo 'src/Modules/Transaction/IFX.Modules.Transaction.Infrastructure/Messaging/TransactionOutboxStore.cs'))
$operationTests = Get-Content -Raw -LiteralPath (Repo 'tests/IFX.IntegrationTests/Runtime/MessagingOperationsTests.cs')
$policyTests = Get-Content -Raw -LiteralPath (Repo 'tests/IFX.IntegrationTests/Runtime/MessageBackpressurePolicyTests.cs')
$healthTests = Get-Content -Raw -LiteralPath (Repo 'tests/IFX.IntegrationTests/Runtime/MessagingHealthTests.cs')
$sqlTests = Get-Content -Raw -LiteralPath (Repo 'tests/IFX.DatabaseBoundary.Tests/Plan02ReliableMessagingSqlServerTests.cs')
$plan = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/02-reliable-integration-events.md')
$closurePack = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/evidence/final-closure/README.md')
$readiness = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/evidence/final-closure/readiness.json') | ConvertFrom-Json -Depth 100

$requiredDimensions = @(
    'moduleId', 'eventCategory', 'pendingCount', 'oldestPendingAge', 'retryCount',
    'deadLetterCount', 'lastSucceeded', 'processingRatePerSecond', 'storageUtilization',
    'expiredLeaseCount', 'duplicateRate', 'consecutiveFailures', 'dispatcherSilence'
)
$repoChecks = [ordered]@{
    noForcedReprocessingDecisionAccepted = $decision.formatVersion -eq 1 -and
        $decision.status -eq 'accepted' -and
        $decision.decision -eq 'forced-business-reprocessing-not-supported' -and
        $decision.enforcement.reprocessingRequestContractExists -eq $false -and
        $decision.enforcement.reprocessingEndpointExists -eq $false
    prohibitedBypassesComplete = @($decision.prohibitedOperations).Count -ge 5 -and
        @($decision.prohibitedOperations | Where-Object { $_ -match 'replacement EventId' }).Count -eq 1 -and
        @($decision.prohibitedOperations | Where-Object { $_ -match 'Inbox marker' }).Count -eq 1
    futureChangeIsSeparatelyGated = $decision.futureChangeGate.newPlanAndAdrRequired -eq $true -and
        $decision.futureChangeGate.separateRequestIdentityRequired -eq $true -and
        $decision.futureChangeGate.originalEventIdReferenceRequired -eq $true -and
        $decision.futureChangeGate.productAndArchitectureApprovalRequired -eq $true -and
        $decision.futureChangeGate.dedicatedIdempotencyAndAuditTestsRequired -eq $true
    noReprocessingContractOrEndpointExists = $runtimeContracts -notmatch '\bReprocessingRequest\b' -and
        $operations -notmatch '\bReprocessingRequest\b' -and
        $endpoints -notmatch '/management/messaging/reprocess'
    immutableDeadLetterReplayEnforced = $runtimeContracts -match 'ReplayDeadLetterAsync\(Guid eventId' -and
        $stores -match 'candidate\.EventId == eventId' -and
        $stores -notmatch 'message\.EventId\s*=(?!=)' -and
        $operations -match 'MESSAGE-NOT-DEAD-LETTERED' -and
        $operations -match 'messaging\.replay\.execute' -and
        $operations -match 'auditSink\.WriteAsync'
    immutableReplayAndInboxDedupeTested = $operationTests -match 'Replay_dry_run_and_execution_preserve_event_id_and_are_audited' -and
        $sqlTests -match 'duplicate_delivery' -and
        $sqlTests -match 'ReplayDeadLetterAsync\(first\.Message\.Envelope\.EventId'
    alertDimensionsAndThresholdsComplete = @(Compare-Object $requiredDimensions @($backpressure.requiredDimensions)).Count -eq 0 -and
        $backpressure.thresholds.warningConsecutiveFailures -lt $backpressure.thresholds.criticalConsecutiveFailures -and
        ([TimeSpan]::Parse($backpressure.thresholds.warningSilence) -lt [TimeSpan]::Parse($backpressure.thresholds.criticalSilence))
    consecutiveFailureAndSilenceSignalsImplemented = $telemetry -match 'ifx\.messaging\.delivery\.consecutive_failures' -and
        $telemetry -match 'ifx\.messaging\.delivery\.seconds_since_success' -and
        $health -match 'DispatcherSilenceSeconds' -and
        $health -match 'ConsecutiveFailures' -and
        $policyTests -match 'Evaluate_ConsecutiveFailures_HasExplicitSeverity' -and
        $policyTests -match 'Evaluate_SilentDispatcher_DoesNotRequireHighMessageVolume' -and
        $healthTests -match 'Probe_surfaces_consecutive_delivery_failures'
    checklistReflectsPartialClosure = $plan -match '- \[x\] E6\.7' -and
        $plan -match '- \[ \] E6\.5' -and
        $plan -match '- \[ \] \*\*Phase 6 完成'
    closurePackReflectsDecision = $closurePack -match 'decision is no longer an external input' -and
        $closurePack -notmatch 'still-open Plan 02 forced'
    readinessReflectsPartialClosure = 'E6.7' -notin @($readiness.plan02.openChecklistItems) -and
        'E6.5' -in @($readiness.plan02.openChecklistItems) -and
        6 -in @($readiness.plan02.phaseCompletionBoxesOpen)
}

$backpressureSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $backpressurePath).Hash.ToLowerInvariant()
$requiredScenarios = @('transport-unavailable', 'sql-unavailable', 'consumer-failure', 'silent-dispatcher')
$thresholds = $alertEvidence.calibratedThresholds
$thresholdsOrdered = $false
try {
    $thresholdsOrdered = [TimeSpan]::Parse([string]$thresholds.warningAge) -lt [TimeSpan]::Parse([string]$thresholds.criticalAge) -and
        [TimeSpan]::Parse([string]$thresholds.warningSilence) -lt [TimeSpan]::Parse([string]$thresholds.criticalSilence) -and
        $thresholds.warningCount -lt $thresholds.criticalCount -and
        $thresholds.warningDeadLetters -lt $thresholds.criticalDeadLetters -and
        $thresholds.warningConsecutiveFailures -lt $thresholds.criticalConsecutiveFailures -and
        $thresholds.criticalStorageUtilization -gt 0 -and $thresholds.criticalStorageUtilization -le 1
}
catch {
    $thresholdsOrdered = $false
}

$targetChecks = [ordered]@{
    completedTargetIdentity = $alertEvidence.formatVersion -eq 1 -and
        $alertEvidence.controlSet -eq 'P02-C3-E6.5' -and
        $alertEvidence.status -eq 'completed' -and
        (Resolved $alertEvidence.releaseId) -and (Resolved $alertEvidence.environment)
    policyDigestMatches = $alertEvidence.backpressurePolicySha256 -eq $backpressureSha256
    noTemplatePlaceholdersRemain = $alertEvidenceText -notmatch '<[^>]+>'
    topologyAndBaselineResolved = $alertEvidence.topology.workerReplicaCount -gt 0 -and
        $alertEvidence.topology.dispatcherConcurrencyPerReplica -gt 0 -and
        (Resolved $alertEvidence.topology.trafficProfileReference) -and
        (Resolved $alertEvidence.topology.baselineWindowReference)
    exporterDashboardRouteAndRunbookResolved = (AllTrue $alertEvidence.telemetry @('dimensionsVerified', 'sensitiveLabelsAbsent')) -and
        @('exporterConfigurationReference', 'dashboardReference', 'alertRuleReference', 'alertRouteReference', 'runbookReference' |
            Where-Object { -not (Resolved $alertEvidence.telemetry.$_) }).Count -eq 0
    calibratedThresholdsOrdered = $thresholdsOrdered
    faultScenariosComplete = @(Compare-Object $requiredScenarios @($alertEvidence.faultScenarios.id)).Count -eq 0 -and
        @($alertEvidence.faultScenarios | Where-Object {
            -not (AllTrue $_ @('triggered', 'routed', 'acknowledged', 'runbookLinked', 'recovered')) -or
            -not (Resolved $_.evidenceReference)
        }).Count -eq 0
    namedApprovalsComplete = @('observability', 'platformOperations', 'platformMessaging' |
        Where-Object { -not (Resolved $alertEvidence.approvals.$_) }).Count -eq 0
    captureTimestampResolved = Timestamp $alertEvidence.capturedAt
}

$failedRepositoryChecks = @($repoChecks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$failedTargetChecks = @($targetChecks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$repositoryPassed = $failedRepositoryChecks.Count -eq 0
$targetPassed = $failedTargetChecks.Count -eq 0
$result = if (-not $repositoryPassed) { 'failed' } elseif ($targetPassed) { 'passed' } else { 'decision-passed-alert-calibration-pending' }
$report = [ordered]@{
    formatVersion = 1
    plan = '02-reliable-integration-events'
    slice = 'P02-C3'
    result = $result
    e6_7 = [ordered]@{ result = if ($repositoryPassed) { 'passed-no-forced-reprocessing' } else { 'failed' }; checklistMayClose = $repositoryPassed }
    e6_5 = [ordered]@{ result = if ($targetPassed) { 'passed' } else { 'target-calibration-pending' }; checklistMayClose = $targetPassed }
    phase6MayClose = $repositoryPassed -and $targetPassed
    repositoryChecks = $repoChecks
    targetChecks = $targetChecks
    failedRepositoryChecks = $failedRepositoryChecks
    failedTargetChecks = $failedTargetChecks
    backpressurePolicySha256 = $backpressureSha256
    nextAction = if ($targetPassed) {
        'Close E6.5 and Plan 02 Phase 6.'
    } else {
        'Populate the production-equivalent alert calibration evidence and rerun with -RequireAlertCalibration.'
    }
}
$resolvedReport = Repo $ReportPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReport) | Out-Null
$report | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $resolvedReport -Encoding utf8NoBOM

if (-not $repositoryPassed) {
    throw "Plan 02 P02-C3 repository validation failed: $($failedRepositoryChecks -join ', '). Report: $resolvedReport"
}
if ($RequireAlertCalibration -and -not $targetPassed) {
    throw "Plan 02 E6.5 target calibration evidence is incomplete: $($failedTargetChecks -join ', '). Report: $resolvedReport"
}
Write-Host "Plan 02 P02-C3 validation result: $result. Report: $resolvedReport"
