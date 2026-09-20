[CmdletBinding()]
param(
    [string]$RepositoryRoot = $(if ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../../../../..')) }),
    [string]$ReportPath = 'docs/architecture/review/evidence/gates/G04/G04-phase12-closeout-report.json'
)

$ErrorActionPreference = 'Stop'
$statusPath = Join-Path $RepositoryRoot 'docs/architecture/review/evidence/gates/G04/G04-phase12-status.json'
$handoffPath = Join-Path $RepositoryRoot 'docs/architecture/review/evidence/gates/G04/G04-phase12-handoff.md'
$planPath = Join-Path $RepositoryRoot 'docs/architecture/review/plans/00-G04-deployment-runtime-boundary.md'
$prerequisitePath = Join-Path $RepositoryRoot 'docs/architecture/review/plans/00-prerequisites.md'
$resolvedReportPath = if ([IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $RepositoryRoot $ReportPath }

$status = Get-Content -Raw -LiteralPath $statusPath | ConvertFrom-Json -Depth 30
$handoff = Get-Content -Raw -LiteralPath $handoffPath
$plan = Get-Content -Raw -LiteralPath $planPath
$prerequisite = Get-Content -Raw -LiteralPath $prerequisitePath
$expectedDependencies = @('Plan 02 E3', 'Plan 02 E4', 'Plan 02 E6', 'Gate 05', 'Plan 03 B2/B3/B4 strict closure', 'Production-like release rehearsal', 'Final approval')

$checks = [ordered]@{}
$checks.statusIsPreReady = $status.status -eq 'PRE-READY'
$checks.gateNotClosed = $status.gateClosed -eq $false -and $status.approvalGranted -eq $false
$checks.allBlockersPresent = @($status.blockers).Count -eq 7 -and (@($status.blockers.id | Sort-Object) -join ',') -eq ((1..7 | ForEach-Object { "G04-B0$_" }) -join ',')
$checks.dependenciesAreComplete = (@($expectedDependencies | Where-Object { $_ -notin $status.blockers.dependency }).Count -eq 0)
$checks.blockerAccountabilityComplete = @($status.blockers | Where-Object {
        [string]::IsNullOrWhiteSpace($_.owner) -or
        [string]::IsNullOrWhiteSpace($_.revisitTrigger) -or
        @($_.requiredEvidence).Count -eq 0
    }).Count -eq 0
$checks.productionParametersOwned = @($status.productionParameters).Count -ge 4 -and @($status.productionParameters | Where-Object {
        [string]::IsNullOrWhiteSpace($_.owner) -or
        [string]::IsNullOrWhiteSpace($_.dueBy) -or
        [string]::IsNullOrWhiteSpace($_.validationEnvironment)
    }).Count -eq 0
$checks.verificationRecorded = $status.verification.closeoutValidator -eq 'passed' -and
    $status.verification.phase12Guard -eq 'passed' -and
    $status.verification.layerGuard.passed -eq 189 -and
    $status.verification.layerGuard.failed -eq 0 -and
    $status.verification.solutionBuild.errors -eq 0 -and
    $status.verification.solutionTests.passed -eq 1091 -and
    $status.verification.solutionTests.failed -eq 0
$checks.b4Returned = ($status.blockers | Where-Object id -eq 'G04-B05').state -eq 'closed-repository-evidence-complete' -and
    @($status.blockers | Where-Object id -eq 'G04-B05').evidence.Count -ge 3
$checks.handoffNamesEveryBlocker = @($status.blockers.id | Where-Object { $handoff -notmatch [regex]::Escape($_) }).Count -eq 0
$checks.phase12NotFalselyClosed = $plan -match '- \[ \] \*\*Phase 12 PRE-READY' -and $plan -notmatch '- \[x\] \*\*Phase 12'
$checks.finalApprovalUnchecked = $plan -match '- \[ \] G04-12\.8'
$checks.prerequisiteGateReleased = $prerequisite -match '- \[x\] \*\*Gate 4 前置放行\*\*'
$checks.phase12EvidenceLinked = $plan -match 'G04-phase12-handoff\.md' -and $plan -match 'G04-phase12-status\.json'

$report = [ordered]@{
    formatVersion = 1
    gate = 'G04'
    phase = 12
    result = if ($checks.Values -contains $false) { 'failed' } else { 'passed' }
    validationMode = 'pre-ready-closeout-no-production-claim'
    checks = $checks
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedReportPath -Encoding utf8NoBOM
if ($report.result -ne 'passed') { throw "G04 Phase 12 closeout validation failed. Report: $resolvedReportPath" }
Write-Host "G04 Phase 12 PRE-READY closeout validation passed. Report: $resolvedReportPath"
