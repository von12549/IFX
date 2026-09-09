[CmdletBinding()]
param(
    [string] $EvidencePath = 'deployment/plan02/full-path-validation-evidence-template.json',
    [string] $ReportPath = 'docs/architecture/review/evidence/plan02/P02-C4-validation.json',
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
function AllTrue([object] $value, [string[]] $properties) {
    return @($properties | Where-Object { $value.$_ -ne $true }).Count -eq 0
}
function Timestamp([object] $value) {
    if (-not (Resolved $value)) { return $null }
    $parsed = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse([string]$value, [ref]$parsed)) { return $null }
    return $parsed
}

$evidencePathResolved = Repo $EvidencePath
$evidenceText = Get-Content -Raw -LiteralPath $evidencePathResolved
$evidence = $evidenceText | ConvertFrom-Json -Depth 100
$databaseTests = Get-Content -Raw -LiteralPath (Repo 'tests/IFX.DatabaseBoundary.Tests/Plan02ReliableMessagingSqlServerTests.cs')
$dispatcherTests = Get-Content -Raw -LiteralPath (Repo 'tests/IFX.IntegrationTests/Runtime/OutboxDispatcherTests.cs')
$inboundTests = Get-Content -Raw -LiteralPath (Repo 'tests/IFX.IntegrationTests/Runtime/InboundIntegrationEventTransportAdapterTests.cs')
$contextTests = Get-Content -Raw -LiteralPath (Repo 'tests/IFX.IntegrationTests/Runtime/HoldingsInboundContextTests.cs')
$observabilityTests = Get-Content -Raw -LiteralPath (Repo 'tests/IFX.IntegrationTests/Observability/SensitiveObservabilityTests.cs')
$failureTests = Get-Content -Raw -LiteralPath (Repo 'tests/IFX.Platform.ProtocolContracts.Tests/FailureReplayCompatibilityConformanceTests.cs')
$httpTests = Get-Content -Raw -LiteralPath (Repo 'tests/IFX.IntegrationTests/Middleware/HttpContextBoundaryTests.cs')
$g05Handback = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/evidence/gates/G05/G05-plan02-b3-handback.md')
$plan = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/02-reliable-integration-events.md')
$runbook = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/runbooks/plan02-reliable-events.md')
$readiness = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/evidence/final-closure/readiness.json') | ConvertFrom-Json -Depth 100

$repositoryChecks = [ordered]@{
    sqlCommitAndFullPathCovered = $databaseTests -match 'Transaction_business_state_and_outbox_commit_or_rollback_together' -and
        $databaseTests -match 'Committed_outbox_event_eventually_changes_consumer_state_once_after_ack_loss'
    duplicateAndIdentityCovered = $databaseTests -match 'Concurrent_duplicate_delivery_commits_one_business_effect_and_one_inbox_marker' -and
        $databaseTests -match 'faultingTransport\.EventIds\.Should\(\)\.Equal\(eventId, eventId\)' -and
        $databaseTests -match 'inbox\.EventId\.Should\(\)\.Be\(eventId\)'
    leaseAndRestartCovered = $databaseTests -match 'Retry_reclaims_same_logical_message_and_stale_lease_cannot_complete' -and
        $dispatcherTests -match 'Crash_before_send_recovers_without_losing_the_logical_message' -and
        $dispatcherTests -match 'Completed_marker_prevents_redelivery_after_restart'
    ackLossAndPartialBatchCovered = $dispatcherTests -match 'Crash_after_send_before_completion_redelivers_the_same_event_id' -and
        $dispatcherTests -match 'Partial_batch_failure_does_not_block_other_partitions' -and
        $databaseTests -match 'transport acknowledgement was lost after delivery'
    boundedFailurePathsCovered = $dispatcherTests -match 'Failed_send_is_retried_without_mutating_logical_identity' -and
        $dispatcherTests -match 'Poison_message_reaches_dead_letter_at_bounded_attempt' -and
        $databaseTests -match 'quarantine_bad_context'
    rawTransportAndContextCovered = $inboundTests -match 'In_process_sender_uses_the_raw_transport_boundary' -and
        $inboundTests -match 'Invalid_business_context_is_quarantined_before_handler_dispatch' -and
        $contextTests -match 'downstream_causation_then_restores_parent'
    g05RepositorySuitesCovered = $observabilityTests -match 'g05-sentinel@example\.invalid' -and
        $failureTests -match 'g05-quarantine-payload-sentinel@example\.invalid' -and
        $httpTests -match 'Diagnostic_endpoint_does_not_echo_sensitive_query_sentinels' -and
        $g05Handback -match 'Protocol, dispatcher,\s*SQL Server and consumer tests provide the repository conformance evidence'
    checklistReflectsTargetPending = $plan -match '- \[ \] E7\.3' -and
        $plan -match '- \[ \] E7\.4' -and
        $plan -match '- \[ \] E7\.8' -and
        $plan -match '- \[ \] \*\*Phase 7 完成'
    runbookBindsStrictTargetGate = $runbook -match 'full-path-validation-evidence-template\.json' -and
        $runbook -match 'Test-Plan02C4FullPath\.ps1' -and
        $runbook -match 'Never mark a scenario complete from the in-process'
    readinessReflectsTargetPending = 'E7.3' -in @($readiness.plan02.openChecklistItems) -and
        'E7.4' -in @($readiness.plan02.openChecklistItems) -and
        'E7.8' -in @($readiness.plan02.openChecklistItems) -and
        @($readiness.plan02.inProgressSlices | Where-Object { $_ -match '^P02-C4/' }).Count -eq 1
}

$requiredFullPathScenarios = @(
    'source-commit-to-consumer-state',
    'duplicate-after-ack-loss',
    'transient-transport-recovery'
)
$requiredFaultScenarios = @(
    'terminate-before-send',
    'terminate-after-send-before-ack',
    'terminate-after-completion',
    'transport-connection-interruption',
    'sql-connection-interruption',
    'handler-timeout',
    'partial-batch',
    'forced-worker-kill-and-lease-takeover',
    'poison-and-quarantine',
    'restart-recovery'
)
$requiredSentinelSurfaces = @('logs', 'traces', 'errors', 'health', 'dead-letter', 'quarantine')
$startedAt = Timestamp $evidence.startedAt
$completedAt = Timestamp $evidence.completedAt
$targetChecks = [ordered]@{
    completedTargetIdentity = $evidence.formatVersion -eq 1 -and
        $evidence.controlSet -eq 'P02-C4-E7.3-E7.4-E7.8' -and
        $evidence.status -eq 'completed' -and
        (Resolved $evidence.releaseId) -and (Resolved $evidence.environment) -and
        [string]$evidence.artifactDigest -match '^sha256:[0-9a-f]{64}$'
    realTransportResolved = (Resolved $evidence.transport.implementation) -and
        [string]$evidence.transport.implementation -notmatch '(?i)in[- ]?process|fake|stub|mock|loopback|test carrier' -and
        (Resolved $evidence.transport.topologyReference) -and
        (Resolved $evidence.transport.networkPolicyReference)
    noTemplatePlaceholdersRemain = $evidenceText -notmatch '<[^>]+>'
    fullPathScenariosComplete = @(Compare-Object $requiredFullPathScenarios @($evidence.fullPathScenarios.id)).Count -eq 0 -and
        @($evidence.fullPathScenarios | Where-Object {
            -not (AllTrue $_ @('passed', 'eventIdentityPreserved', 'consumerStateVerified')) -or
            -not (Resolved $_.evidenceReference)
        }).Count -eq 0
    faultMatrixComplete = @(Compare-Object $requiredFaultScenarios @($evidence.faultScenarios.id)).Count -eq 0 -and
        @($evidence.faultScenarios | Where-Object {
            -not (AllTrue $_ @('injected', 'durableTruthPreserved', 'recovered')) -or
            -not (Resolved $_.evidenceReference)
        }).Count -eq 0
    g05PropagationAndIsolationComplete = (AllTrue $evidence.g05Conformance @(
            'httpProducerToDownstreamPassed',
            'retryReplayImmutabilityPassed',
            'parallelTenantIsolationPassed',
            'boundedIdentityDimensionsOnly')) -and
        (Resolved $evidence.g05Conformance.evidenceReference)
    sensitiveSentinelMatrixComplete = @(Compare-Object $requiredSentinelSurfaces @($evidence.g05Conformance.sentinelSurfaces.surface)).Count -eq 0 -and
        @($evidence.g05Conformance.sentinelSurfaces | Where-Object {
            $_.sentinelAbsent -ne $true -or -not (Resolved $_.evidenceReference)
        }).Count -eq 0
    namedApprovalsComplete = @(
        'testEngineering', 'platformMessaging', 'security', 'producerModuleOwner',
        'consumerModuleOwner', 'database', 'operations' |
            Where-Object { -not (Resolved $evidence.approvals.$_) }).Count -eq 0
    timestampsCompleteAndOrdered = $null -ne $startedAt -and $null -ne $completedAt -and $startedAt -le $completedAt
}

$failedRepositoryChecks = @($repositoryChecks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$failedTargetChecks = @($targetChecks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$repositoryPassed = $failedRepositoryChecks.Count -eq 0
$targetPassed = $failedTargetChecks.Count -eq 0
$result = if (-not $repositoryPassed) { 'failed' } elseif ($targetPassed) { 'passed' } else { 'repository-passed-target-full-path-pending' }
$report = [ordered]@{
    formatVersion = 1
    plan = '02-reliable-integration-events'
    slice = 'P02-C4'
    result = $result
    e7_3 = [ordered]@{ result = if ($targetPassed) { 'passed' } else { 'target-real-transport-pending' }; checklistMayClose = $targetPassed }
    e7_4 = [ordered]@{ result = if ($targetPassed) { 'passed' } else { 'target-fault-matrix-pending' }; checklistMayClose = $targetPassed }
    e7_8 = [ordered]@{ result = if ($targetPassed) { 'passed' } else { 'target-g05-suite-pending' }; checklistMayClose = $targetPassed }
    phase7MayClose = $false
    repositoryChecks = $repositoryChecks
    targetChecks = $targetChecks
    failedRepositoryChecks = $failedRepositoryChecks
    failedTargetChecks = $failedTargetChecks
    nextAction = if ($targetPassed) {
        'Close E7.3, E7.4 and E7.8; keep Phase 7 open until E7.5 and E7.6 close.'
    } else {
        'Run the full path, fault matrix and G05 sentinel suite in the selected production-equivalent environment, then rerun with -RequireTargetEvidence.'
    }
}
$resolvedReport = Repo $ReportPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReport) | Out-Null
$report | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $resolvedReport -Encoding utf8NoBOM

if (-not $repositoryPassed) {
    throw "Plan 02 P02-C4 repository validation failed: $($failedRepositoryChecks -join ', '). Report: $resolvedReport"
}
if ($RequireTargetEvidence -and -not $targetPassed) {
    throw "Plan 02 P02-C4 target evidence is incomplete: $($failedTargetChecks -join ', '). Report: $resolvedReport"
}
Write-Host "Plan 02 P02-C4 validation result: $result. Report: $resolvedReport"
