[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $EvidencePath
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$resolvedPath = if ([System.IO.Path]::IsPathRooted($EvidencePath)) {
    $EvidencePath
} else {
    Join-Path $repositoryRoot $EvidencePath
}

if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
    throw "G02 rollout evidence file was not found: $resolvedPath"
}

$raw = Get-Content -Raw -LiteralPath $resolvedPath
if ($raw -match '<[^>]+>') {
    throw "G02 rollout evidence still contains template placeholders."
}
$evidence = $raw | ConvertFrom-Json -Depth 100

$requiredText = @(
    $evidence.releaseId,
    $evidence.environment,
    $evidence.changeTicket,
    $evidence.approvals.architecture,
    $evidence.approvals.database,
    $evidence.approvals.operations,
    $evidence.preflight.reportReference,
    $evidence.preflight.classification,
    $evidence.preflight.reviewedBy,
    $evidence.restorePoint.identifier,
    $evidence.restorePoint.restoreVerificationReference,
    $evidence.execution.migrationJobReference,
    $evidence.execution.applyReportReference,
    $evidence.execution.validationReportReference,
    $evidence.execution.operator,
    $evidence.compatibilityWindow.smokeTestReference,
    $evidence.compatibilityWindow.rollbackVerificationReference,
    $evidence.runtimeIdentity.permissionReportReference,
    $evidence.sharedHistory.archiveReference
)
if (@($requiredText | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) {
    throw "G02 rollout evidence has missing required references."
}

$hashes = @(
    $evidence.artifacts.migrationManifestSha256,
    $evidence.artifacts.releaseManifestSha256,
    $evidence.artifacts.artifactManifestSha256,
    $evidence.preflight.reportSha256,
    $evidence.execution.applyReportSha256,
    $evidence.execution.validationReportSha256
)
if (@($hashes | Where-Object { $_ -cnotmatch '^[0-9a-f]{64}$' }).Count -gt 0) {
    throw "G02 rollout evidence contains an invalid SHA-256 value."
}

$requiredTrue = @(
    $evidence.preflight.historyMappingReviewed,
    $evidence.preflight.fingerprintReviewed,
    $evidence.restorePoint.restoreVerified,
    $evidence.execution.apiStartedAfterValidation,
    $evidence.compatibilityWindow.migrationStable,
    $evidence.compatibilityWindow.readinessStable,
    $evidence.compatibilityWindow.businessReadWriteStable,
    $evidence.compatibilityWindow.rollbackCompatibilityVerified,
    $evidence.runtimeIdentity.dmlVerified,
    $evidence.runtimeIdentity.readinessVerified,
    $evidence.runtimeIdentity.ddlDenied,
    $evidence.runtimeIdentity.legacyRuntimeMigrationEntryPointsAbsent,
    $evidence.sharedHistory.rowsPreserved
)
if ($requiredTrue -contains $false) {
    throw "G02 rollout evidence has an unverified required control."
}
if ($evidence.status -ne "completed" -or $evidence.execution.validationResult -ne "succeeded") {
    throw "G02 rollout evidence is not completed with successful validation."
}
if ($evidence.sharedHistory.mode -notin @("archived-read-only", "not-present-fresh") -or
    $evidence.sharedHistory.deletionApproved) {
    throw "G02 shared history must be retained archived/read-only or verified absent on fresh state, without deletion approval."
}

$timestamps = @(
    $evidence.preflight.reviewedAt,
    $evidence.restorePoint.verifiedAt,
    $evidence.execution.startedAt,
    $evidence.execution.finishedAt,
    $evidence.compatibilityWindow.startedAt,
    $evidence.compatibilityWindow.finishedAt
)
foreach ($timestamp in $timestamps) {
    $parsed = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse($timestamp, [ref] $parsed)) {
        throw "G02 rollout evidence contains an invalid timestamp."
    }
}

Write-Host "G02 rollout evidence passed: $resolvedPath"
