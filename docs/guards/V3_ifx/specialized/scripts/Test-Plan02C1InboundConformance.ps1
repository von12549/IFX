[CmdletBinding()]
param(
    [string] $ReportPath = 'docs/architecture/review/evidence/plan02/P02-C1-validation.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = if ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..')) }
function Repo([string] $path) {
    if ([IO.Path]::IsPathRooted($path)) { return $path }
    return Join-Path $repositoryRoot $path
}

$receiver = Get-Content -Raw -LiteralPath (Repo 'src/Platform/Messaging/IFX.Platform.Messaging.Runtime/RawIntegrationEventReceiver.cs')
$sender = Get-Content -Raw -LiteralPath (Repo 'src/Platform/Messaging/IFX.Platform.Messaging.Runtime/InProcessIntegrationEventTransport.cs')
$registration = Get-Content -Raw -LiteralPath (Repo 'src/Platform/Messaging/IFX.Platform.Messaging.Runtime/MessagingServiceCollectionExtensions.cs')
$tests = Get-Content -Raw -LiteralPath (Repo 'tests/IFX.IntegrationTests/Runtime/InboundIntegrationEventTransportAdapterTests.cs')
$plan = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/02-reliable-integration-events.md')
$readiness = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/evidence/final-closure/readiness.json') | ConvertFrom-Json -Depth 50
$status = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/evidence/plan02/P02-C1-status.json') | ConvertFrom-Json -Depth 50

$checks = [ordered]@{
    rawCarrierAndReceiverExist = ($receiver -match 'record InboundIntegrationEventMessage') -and
        ($receiver -match 'interface IInboundIntegrationEventReceiver') -and
        ($receiver -match 'class RawIntegrationEventReceiver')
    currentSenderUsesRawBoundary = ($sender -match 'IntegrationEventTransportCodec\.Encode') -and
        ($sender -match 'receiver\.ReceiveAsync')
    receiverRegistered = $registration -match 'AddSingleton<IInboundIntegrationEventReceiver, RawIntegrationEventReceiver>'
    contextValidatedBeforeHandler = ($receiver.IndexOf('IntegrationEventTransportCodec.Decode') -lt $receiver.IndexOf('GetServices<IInboundIntegrationEventHandler>')) -and
        ($receiver -match 'G05-EVENT-CONTEXT-INVALID') -and
        ($receiver -match 'G05-EVENT-TENANT-INVALID')
    invalidTraceRestartsAndSanitizes = ($receiver -match 'ActivityContext\.TryParse') -and
        ($receiver -match 'traceRestarted = true') -and
        ($receiver -match 'parentContext = default') -and
        ($receiver -match 'ActivityKind\.Consumer')
    boundedTraceTelemetry = ($receiver -match 'ifx\.trace\.restarted') -and
        ($receiver -notmatch 'ILogger|Log(?:Trace|Debug|Information|Warning|Error|Critical)\s*\(')
    testsCoverInvalidTraceParentAndState = ($tests -match 'Invalid_trace_is_restarted_and_sanitized_before_the_real_handler') -and
        ($tests -match 'damaged-trace') -and
        ($tests -match 'invalid\\nstate')
    testsCoverContextBeforeHandler = ($tests -match 'Invalid_business_context_is_quarantined_before_handler_dispatch') -and
        ($tests -match 'handler\.Messages\.Should\(\)\.BeEmpty')
    testsCoverValidParentAndCurrentTransport = ($tests -match 'Valid_remote_trace_is_continued_without_changing_the_envelope') -and
        ($tests -match 'In_process_sender_uses_the_raw_transport_boundary')
    checklistClosed = ($plan -match '- \[x\] \*\*Phase 4 完成') -and
        ($plan -match '- \[x\] E4\.9')
    evidenceRecorded = $status.result -eq 'passed' -and
        $status.verification.solutionTests.passed -eq 1085 -and
        $status.verification.solutionTests.failed -eq 0 -and
        $status.verification.layerGuard.findings -eq 0
    readinessAdvancedOnlyOneSlice = 'P02-C1/E4.9' -in @($readiness.plan02.closedSlices) -and
        'E4.9' -notin @($readiness.plan02.openChecklistItems) -and
        @($readiness.plan02.phaseCompletionBoxesOpen) -join ',' -eq '5,6,7,8'
}

$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$report = [ordered]@{
    formatVersion = 1
    plan = '02-reliable-integration-events'
    slice = 'P02-C1'
    result = if ($failed.Count -eq 0) { 'passed' } else { 'failed' }
    checks = $checks
    failedChecks = $failed
    nextSlice = 'P02-C2 / E5.7 target data controls'
}

$resolved = Repo $ReportPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolved) | Out-Null
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolved -Encoding utf8NoBOM
if ($failed.Count -gt 0) {
    throw "Plan 02 P02-C1 validation failed: $($failed -join ', '). Report: $resolved"
}

Write-Host "Plan 02 P02-C1 validation passed: $resolved"
