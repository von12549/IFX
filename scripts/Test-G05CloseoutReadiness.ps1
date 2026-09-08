[CmdletBinding()]
param([string] $ReportPath = 'docs/architecture/review/evidence/gates/G05/G05-phase11-status.json')

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
function Repo([string] $path) { Join-Path $repositoryRoot $path }

$inventory = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/evidence/gates/G05/G05-context-inventory.json') | ConvertFrom-Json -Depth 50
$catalog = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/gates/G03/contract-event-catalog.yaml') | ConvertFrom-Json -Depth 100
$openItems = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/gates/G05/open-items-v1.json') | ConvertFrom-Json -Depth 30
$opsMap = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/gates/G05/ops-evidence-map-v1.json') | ConvertFrom-Json -Depth 30
$observability = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/gates/G05/observability-security-policy.json') | ConvertFrom-Json -Depth 30
$g03Status = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/evidence/gates/G03/G03-phase9-status.json') | ConvertFrom-Json -Depth 30
$verification = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/evidence/gates/G05/G05-phase9-verification-summary.json') | ConvertFrom-Json -Depth 30
$master = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/00-G05-context-sensitive-data-boundary.md')
$prerequisites = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/00-prerequisites.md')

$handoffs = @(
    'docs/architecture/review/gates/G05/handoffs/plan01-contract-context-handoff.md',
    'docs/architecture/review/gates/G05/handoffs/plan02-event-context-handoff.md',
    'docs/architecture/review/gates/G05/handoffs/plan03-layerguard-handoff.md',
    'docs/architecture/review/gates/G05/handoffs/g04-runtime-handoff.md'
)
$catalogExceptionIds = @($catalog.fieldExceptions.id | Sort-Object)
$openExceptionIds = @($openItems.fieldExceptions.exceptionRef | Sort-Object)
$backupOwnerBlocker = @($g03Status.blockers | Where-Object code -eq 'backup-owner-unassigned')
$checks = [ordered]@{
    allFourHandoffsExist = @($handoffs | Where-Object { -not (Test-Path (Repo $_)) }).Count -eq 0
    opsEvidenceMapCoversRequiredSet = (@($opsMap.requirements.id | Sort-Object) -join ',') -eq 'OPS-G1,OPS1,OPS3' -and $opsMap.status -eq 'repository-complete-downstream-pending'
    repositoryVerificationPassed = $verification.result -eq 'passed' -and $verification.solutionTests.passed -ge 1041 -and $verification.solutionTests.failed -eq 0
    realContractAndMessagingEvidenceStillPending = -not $inventory.messagingCapabilities.durableOutboxImplemented -and -not $inventory.messagingCapabilities.durableInboxImplemented -and -not $inventory.messagingCapabilities.deadLetterOrQuarantineImplemented -and -not $inventory.messagingCapabilities.replayOrReprocessingImplemented
    productionSecurityEvidenceStillPending = $observability.productionEvidence.status -eq 'pending' -and $observability.authTokenPersistence.deploymentStatus -match '^pending '
    blockersAreOwnedRiskedAndRevisitable = @($openItems.blockers).Count -ge 7 -and @($openItems.blockers | Where-Object { [string]::IsNullOrWhiteSpace($_.owner) -or [string]::IsNullOrWhiteSpace($_.risk) -or [string]::IsNullOrWhiteSpace($_.revisitWhen) -or @($_.blocks).Count -eq 0 }).Count -eq 0
    everyC3ExceptionIsTrackedWithExpiry = ($catalogExceptionIds -join ',') -eq ($openExceptionIds -join ',') -and @($openItems.fieldExceptions).Count -eq 8 -and @($openItems.fieldExceptions | Where-Object { [string]::IsNullOrWhiteSpace($_.owner) -or [string]::IsNullOrWhiteSpace($_.risk) -or [string]::IsNullOrWhiteSpace($_.expiresAt) -or @($_.blocks).Count -eq 0 }).Count -eq 0
    g03BackupOwnerAssignmentResolved = $backupOwnerBlocker.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($catalog.approvalPolicy.backupOwner) -and 'G05-B06' -notin @($openItems.blockers.code)
    prerequisiteGateReleased = $prerequisites -match '(?m)^- \[x\] \*\*Gate 5 前置放行\*\*'
    phase11AndFinalApprovalRemainOpen = $master -match '(?m)^- \[ \] \*\*Phase 11 完成\*\*' -and $master -match '(?m)^- \[x\] G05-11\.6' -and $master -match '(?m)^- \[ \] G05-11\.8'
}

$report = [ordered]@{
    formatVersion = 1
    gate = 'G05'
    phase = 11
    result = if ($checks.Values -contains $false) { 'failed' } else { 'passed' }
    closureStatus = 'pre-ready'
    readyForClosure = $false
    checkedAt = '2026-09-08'
    checks = $checks
    counts = [ordered]@{
        handoffs = $handoffs.Count
        opsRequirements = @($opsMap.requirements).Count
        blockers = @($openItems.blockers).Count
        c3Exceptions = @($openItems.fieldExceptions).Count
        solutionTests = $verification.solutionTests.passed
    }
    blockers = $openItems.blockers
    fieldExceptions = $openItems.fieldExceptions
}

$resolved = if ([IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Repo $ReportPath }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolved) | Out-Null
$report | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $resolved -Encoding utf8NoBOM
if ($report.result -ne 'passed') { throw "G05 closeout readiness audit failed: $resolved" }
Write-Host "G05 closeout audit passed with PRE-READY status: $resolved"
