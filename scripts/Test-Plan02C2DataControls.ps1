[CmdletBinding()]
param(
    [string] $PolicyPath = "deployment/plan02/messaging-data-controls.json",
    [string] $EvidencePath = "deployment/plan02/messaging-data-controls-evidence-template.json",
    [string] $ReportPath = "docs/architecture/review/evidence/plan02/P02-C2-validation.json",
    [switch] $RequireTargetEvidence
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
function Repo([string] $path) {
    if ([IO.Path]::IsPathRooted($path)) { return $path }
    return Join-Path $repositoryRoot $path
}

function IsResolvedReference([object] $value) {
    return $null -ne $value -and
        -not [string]::IsNullOrWhiteSpace([string]$value) -and
        [string]$value -notmatch '<[^>]+>'
}

function AllTrue([object] $object, [string[]] $properties) {
    return @($properties | Where-Object { $object.$_ -ne $true }).Count -eq 0
}

function IsTimestamp([object] $value) {
    if (-not (IsResolvedReference $value)) { return $false }
    $parsed = [DateTimeOffset]::MinValue
    return [DateTimeOffset]::TryParse([string]$value, [ref]$parsed)
}

$resolvedPolicy = Repo $PolicyPath
$resolvedEvidence = Repo $EvidencePath
$policy = Get-Content -Raw -LiteralPath $resolvedPolicy | ConvertFrom-Json -Depth 100
$evidenceText = Get-Content -Raw -LiteralPath $resolvedEvidence
$evidence = $evidenceText | ConvertFrom-Json -Depth 100
$catalog = Get-Content -Raw -LiteralPath (Repo $policy.authorities.fieldCatalog) | ConvertFrom-Json -Depth 100
$eventFields = @($catalog.protocols | Where-Object kind -eq 'event' | ForEach-Object fields)

$requiredStores = @(
    'producer-outbox',
    'consumer-inbox',
    'broker',
    'dead-letter',
    'quarantine',
    'replay-audit',
    'diagnostics'
)
$requiredAssignments = @('producer', 'dispatcher', 'consumer', 'diagnostics', 'replay-operator')
$requiredAtRest = @('database', 'broker', 'dead-letter', 'quarantine', 'replay-audit', 'backup', 'diagnostic-sink')
$requiredSchedules = @('producer-outbox', 'consumer-inbox', 'broker', 'dead-letter', 'quarantine', 'replay-audit', 'diagnostics')
$requiredExceptionFields = @('id', 'owner', 'purpose', 'fields', 'producer', 'consumers', 'approvals', 'expiresAt', 'revocationCondition', 'deletionCondition')

$repoChecks = [ordered]@{
    formatAndFailClosed = $policy.formatVersion -eq 1 -and $policy.failClosed -eq $true -and
        $policy.status -eq 'repository-baseline-target-attestation-pending'
    soleAuthoritiesReferenced = (IsResolvedReference $policy.authorities.fieldCatalog) -and
        (Test-Path -LiteralPath (Repo $policy.authorities.fieldCatalog)) -and
        (IsResolvedReference $policy.authorities.observabilityPolicy) -and
        (Test-Path -LiteralPath (Repo $policy.authorities.observabilityPolicy)) -and
        (IsResolvedReference $policy.authorities.operationsRunbook) -and
        (Test-Path -LiteralPath (Repo $policy.authorities.operationsRunbook))
    classificationCeilingIsC2AndC4Denied = $policy.classification.currentEventPayloadCeiling -eq 'C2' -and
        $policy.classification.c4Allowed -eq $false -and
        $policy.classification.unknownFields -eq 'deny' -and
        $policy.classification.storageInheritsHighestPayloadClassification -eq $true
    catalogEventsRespectDeclaredCeiling = $eventFields.Count -gt 0 -and
        @($eventFields | Where-Object classification -in @('C3', 'C4')).Count -eq 0 -and
        @($eventFields | Where-Object classification -eq 'C2').Count -gt 0
    allStoresCovered = @(Compare-Object $requiredStores @($policy.stores.id)).Count -eq 0 -and
        @($policy.stores | Where-Object classification -ne 'C2').Count -eq 0
    leastPrivilegeRolesComplete = @(Compare-Object $requiredAssignments @($policy.access.assignments.id)).Count -eq 0 -and
        $policy.access.separateWorkloadIdentitiesRequired -eq $true -and
        $policy.access.sharedAdministratorRuntimeIdentityAllowed -eq $false -and
        $policy.access.directHumanTableAccessAllowed -eq $false -and
        $policy.access.accessAuditRequired -eq $true -and
        $policy.access.negativePermissionTestsRequired -eq $true
    diagnosticAndReplayBypassesDenied = 'read payload' -in @($policy.access.assignments | Where-Object id -eq 'diagnostics').deny -and
        'direct table DML' -in @($policy.access.assignments | Where-Object id -eq 'replay-operator').deny
    transportEncryptionFailsClosed = $policy.encryption.inTransit.required -eq $true -and
        [version]$policy.encryption.inTransit.minimumTls -ge [version]'1.2' -and
        $policy.encryption.inTransit.certificateValidationRequired -eq $true -and
        $policy.encryption.inTransit.trustServerCertificateAllowedInProduction -eq $false
    atRestSecretsAndRotationCovered = $policy.encryption.atRest.required -eq $true -and
        @(Compare-Object $requiredAtRest @($policy.encryption.atRest.covers)).Count -eq 0 -and
        $policy.encryption.atRest.externalKeyManagementRequired -eq $true -and
        $policy.encryption.atRest.rotationEvidenceRequired -eq $true -and
        $policy.encryption.secrets.externalSecretStoreRequired -eq $true -and
        $policy.encryption.secrets.plaintextRepositorySecretAllowed -eq $false -and
        $policy.encryption.secrets.rotationEvidenceRequired -eq $true
    lifecycleInventoryCompleteButApprovalPending = @(Compare-Object $requiredSchedules @($policy.lifecycle.proposedSchedules.store | Select-Object -Unique)).Count -eq 0 -and
        $policy.lifecycle.approvalStatus -eq 'pending-security-legal-and-data-owner-approval' -and
        @($policy.lifecycle.proposedSchedules | Where-Object { [string]::IsNullOrWhiteSpace($_.action) }).Count -eq 0
    pendingAndLegalHoldSafetyDefined = @($policy.lifecycle.proposedSchedules | Where-Object {
            $_.store -eq 'producer-outbox' -and $_.state -eq 'Pending' -and $null -eq $_.proposedDuration -and $_.action -match 'never age-delete'
        }).Count -eq 1 -and
        $policy.lifecycle.legalHold.suspendsDeletion -eq $true -and
        $policy.lifecycle.legalHold.payloadExpansionAllowed -eq $false -and
        $policy.lifecycle.tenantDeletion.legalHoldTakesPrecedence -eq $true -and
        $policy.lifecycle.tenantDeletion.requiresReconciliationBeforeDeletion -eq $true -and
        $policy.lifecycle.tenantDeletion.tombstoneContainsPayload -eq $false
    c3StateTransferDefaultsToDeny = $policy.c3StateTransfer.default -eq 'deny' -and
        @($policy.c3StateTransfer.activeExceptions).Count -eq 0 -and
        $policy.c3StateTransfer.expiredExceptionBehavior -eq 'fail-closed' -and
        @(Compare-Object $requiredExceptionFields @($policy.c3StateTransfer.requiredExceptionFields)).Count -eq 0
    closureContractRequiresTargetEvidence = $policy.closure.requiresImmutableTargetReferences -eq $true -and
        @(Compare-Object @('security', 'database', 'platformOperations', 'legalOrDataOwner') @($policy.closure.requiresNamedApprovals)).Count -eq 0
}

$policySha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedPolicy).Hash.ToLowerInvariant()
$targetChecks = [ordered]@{
    formatAndCompletedTargetIdentity = $evidence.formatVersion -eq 1 -and
        $evidence.plan -eq '02-reliable-integration-events' -and
        $evidence.controlSet -eq 'P02-C2' -and
        $evidence.status -eq 'completed' -and
        (IsResolvedReference $evidence.releaseId) -and
        (IsResolvedReference $evidence.environment)
    policyDigestMatches = $evidence.policySha256 -eq $policySha256
    noTemplatePlaceholdersRemain = $evidenceText -notmatch '<[^>]+>'
    accessEvidenceComplete = (AllTrue $evidence.access @(
            'separateWorkloadIdentitiesVerified',
            'sharedAdministratorRuntimeIdentityAbsent',
            'diagnosticPayloadReadDenied',
            'directReplayTableDmlDenied'
        )) -and @(
            'workloadIdentityConfigurationReference',
            'databaseAclReference',
            'brokerAclReference',
            'diagnosticAclReference',
            'accessAuditReference',
            'positivePermissionTestReference',
            'negativePermissionTestReference' |
                Where-Object { -not (IsResolvedReference $evidence.access.$_) }
        ).Count -eq 0
    encryptionEvidenceComplete = (AllTrue $evidence.encryption @(
            'tls12OrLaterVerified',
            'certificateValidationVerified',
            'atRestCoverageVerified',
            'plaintextRepositorySecretAbsent'
        )) -and @(
            'databaseTransportReference',
            'brokerTransportReference',
            'atRestConfigurationReference',
            'backupEncryptionReference',
            'diagnosticSinkEncryptionReference',
            'externalSecretStoreReference',
            'keyRotationReference' |
                Where-Object { -not (IsResolvedReference $evidence.encryption.$_) }
        ).Count -eq 0
    lifecycleEvidenceComplete = (AllTrue $evidence.lifecycle @(
            'pendingMessagesAgeDeleteDenied',
            'replayWindowPreserved',
            'legalHoldSuspendsDeletion',
            'deletionAuditVerified'
        )) -and @(
            'approvedScheduleReference',
            'retentionConfigurationReference',
            'deletionJobReference',
            'retentionRehearsalReference',
            'tenantDeletionRehearsalReference',
            'legalHoldRehearsalReference',
            'restoreDrillReference' |
                Where-Object { -not (IsResolvedReference $evidence.lifecycle.$_) }
        ).Count -eq 0
    c3EvidenceComplete = $evidence.c3StateTransfer.activeExceptionCount -eq @($policy.c3StateTransfer.activeExceptions).Count -and
        $evidence.c3StateTransfer.unregisteredTransferDenied -eq $true -and
        $evidence.c3StateTransfer.expiredTransferDenied -eq $true -and
        (IsResolvedReference $evidence.c3StateTransfer.registryReference)
    namedApprovalsComplete = @('security', 'database', 'platformOperations', 'legalOrDataOwner' |
            Where-Object { -not (IsResolvedReference $evidence.approvals.$_) }).Count -eq 0
    captureTimestampResolved = IsTimestamp $evidence.capturedAt
}

$failedRepositoryChecks = @($repoChecks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$failedTargetChecks = @($targetChecks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$repositoryPassed = $failedRepositoryChecks.Count -eq 0
$targetPassed = $failedTargetChecks.Count -eq 0
$result = if (-not $repositoryPassed) {
    'failed'
}
elseif ($targetPassed) {
    'passed'
}
else {
    'repository-passed-target-evidence-pending'
}

$report = [ordered]@{
    formatVersion = 1
    plan = '02-reliable-integration-events'
    slice = 'P02-C2'
    item = 'E5.7'
    result = $result
    repositoryChecks = $repoChecks
    targetChecks = $targetChecks
    failedRepositoryChecks = $failedRepositoryChecks
    failedTargetChecks = $failedTargetChecks
    policySha256 = $policySha256
    evidencePath = $EvidencePath
    checklistMayClose = $targetPassed
    nextAction = if ($targetPassed) {
        'Record immutable evidence and close E5.7/Phase 5.'
    }
    else {
        'Populate a copy of the target evidence template from the production-candidate environment, obtain named approvals, and rerun with -RequireTargetEvidence.'
    }
}

$resolvedReport = Repo $ReportPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReport) | Out-Null
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedReport -Encoding utf8NoBOM

if (-not $repositoryPassed) {
    throw "Plan 02 P02-C2 repository policy validation failed: $($failedRepositoryChecks -join ', '). Report: $resolvedReport"
}
if ($RequireTargetEvidence -and -not $targetPassed) {
    throw "Plan 02 P02-C2 target evidence is incomplete: $($failedTargetChecks -join ', '). Report: $resolvedReport"
}

Write-Host "Plan 02 P02-C2 validation result: $result. Report: $resolvedReport"
