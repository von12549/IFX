[CmdletBinding()]
param([string] $ReportPath = 'docs/architecture/review/evidence/plan00-prerequisite-release-status.json')

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
function Repo([string] $path) { Join-Path $repositoryRoot $path }

$prerequisites = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/00-prerequisites.md')
$master = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/00-master-plan.md')
$g03Plan = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/00-G03-contract-event-governance.md')
$g04Plan = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/00-G04-deployment-runtime-boundary.md')
$g05Plan = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/00-G05-context-sensitive-data-boundary.md')
$g03Status = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/evidence/gates/G03/G03-phase9-status.json') | ConvertFrom-Json -Depth 30
$g04Status = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/evidence/gates/G04/G04-phase12-status.json') | ConvertFrom-Json -Depth 30
$g05Status = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/evidence/gates/G05/G05-phase11-status.json') | ConvertFrom-Json -Depth 30

$checks = [ordered]@{
    bootstrapComplete = $prerequisites -match '(?m)^- \[x\] \*\*LG-BOOTSTRAP\*\*'
    preReadyReleased = $prerequisites -match '(?m)^- \[x\] \*\*PRE-READY 前置放行\*\*'
    allFiveGatesReleased = @(1..5 | Where-Object { $prerequisites -notmatch "(?m)^- \[x\] \*\*Gate $_ 前置放行\*\*" }).Count -eq 0
    preReadyAcceptanceComplete = @(1..7 | Where-Object { $prerequisites -notmatch "(?m)^- \[x\] PRE-D0$_ " }).Count -eq 0
    policyReadyComplete = $prerequisites -match '(?m)^- \[x\] \*\*LG-POLICY-READY\*\*' -and @(1..3 | Where-Object { $prerequisites -notmatch "(?m)^- \[x\] LG-D0$_ " }).Count -eq 0
    finalClosureStillOpen = $prerequisites -match '(?m)^- \[ \] \*\*Gate 最终关闭\*\*'
    masterPrerequisiteReleased = $master -match '(?m)^- \[x\] M-PRE '
    masterPhase0Complete =
        $master -match '(?m)^- \[x\] \*\*Phase 0 完成\*\*' -and
        @(1..6 | Where-Object { $master -notmatch "(?m)^- \[x\] M0\.$_ " }).Count -eq 0 -and
        $master -match '(?m)^\| Plan 03 — LayerGuard policy binding \| `@von12549` \| 03-A1 / 正式 B1 \| Junxi \(`@jimkeecn`\) \|$' -and
        $master -match '(?m)^\| G01/G02 事务与数据库回交 \| `@von12549` \| Plan 02 E2/E4 回交并通过 G01/G02 conformance \| Junxi \(`@jimkeecn`\) \|$'
    masterPhase1Complete = $master -match '(?m)^- \[x\] \*\*Phase 1 完成\*\*' -and @(1..6 | Where-Object { $master -notmatch "(?m)^- \[x\] M1\.$_ " }).Count -eq 0
    gatePlansSeparateReleaseFromClosure =
        $g03Plan -match '(?m)^- \[x\] G03-9\.7 ' -and $g03Plan -match '(?m)^- \[ \] G03-9\.8 ' -and
        $g04Plan -match '(?m)^- \[x\] G04-12\.6 ' -and $g04Plan -match '(?m)^- \[ \] G04-12\.8 ' -and
        $g05Plan -match '(?m)^- \[x\] G05-11\.6 ' -and $g05Plan -match '(?m)^- \[ \] G05-11\.8 '
    noGateFalselyClosed = -not $g03Status.readyForClosure -and -not $g04Status.gateClosed -and -not $g04Status.approvalGranted -and -not $g05Status.readyForClosure
    downstreamBlockersRemainVisible = $g03Status.counts.blockers -eq 4 -and @($g04Status.blockers).Count -eq 7 -and $g05Status.counts.blockers -eq 7
    evidenceDocumentExists = Test-Path -LiteralPath (Repo 'docs/architecture/review/evidence/plan00-prerequisite-release.md')
}

$report = [ordered]@{
    formatVersion = 1
    plan = 'Plan 00'
    result = if ($checks.Values -contains $false) { 'failed' } else { 'passed' }
    milestone = 'PRE-READY'
    prerequisiteReleased = $true
    lgPolicyReady = $true
    gateFinalClosure = $false
    checkedAt = '2026-09-08'
    checks = $checks
    retainedBlockers = [ordered]@{ G03 = $g03Status.counts.blockers; G04 = @($g04Status.blockers).Count; G05 = $g05Status.counts.blockers }
    next = 'Begin Plan 01 Contracts / Ports / Adapters migration under the frozen B1 target policy, then save B2 before Plan 02/B3.'
}

$resolvedReportPath = if ([IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Repo $ReportPath }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedReportPath -Encoding utf8NoBOM
if ($report.result -ne 'passed') { throw "Plan 00 prerequisite release validation failed: $resolvedReportPath" }
Write-Host "Plan 00 PRE-READY prerequisite release validation passed: $resolvedReportPath"
