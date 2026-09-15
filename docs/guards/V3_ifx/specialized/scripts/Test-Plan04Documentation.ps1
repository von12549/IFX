[CmdletBinding()]
param([string] $StatusPath = 'docs/architecture/review/evidence/plan04/phase8-documentation-status.json')

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
function Repo([string] $path) { if ([IO.Path]::IsPathRooted($path)) { return $path }; Join-Path $repositoryRoot $path }
function ReadJson([string] $path) { Get-Content -Raw -LiteralPath (Repo $path) | ConvertFrom-Json -Depth 100 }

$zhPath = 'docs/architecture/review/module-boundary-evolution.zh-CN.md'
$enPath = 'docs/architecture/review/module-boundary-evolution.en.md'
$zh = Get-Content -Raw -LiteralPath (Repo $zhPath)
$en = Get-Content -Raw -LiteralPath (Repo $enPath)
$plan = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/04-module-boundary-evolution.md')
$master = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/00-master-plan.md')
$planIndex = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/README.md')
$todo = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/TODO.md')
$map = ReadJson 'docs/architecture/review/evidence/plan04/rule-validation-map.json'
$phase2 = ReadJson 'docs/architecture/review/evidence/plan04/phase2-audit-status.json'
$phase3 = ReadJson 'docs/architecture/review/evidence/plan04/phase3-extraction-policy-status.json'
$phase7 = ReadJson 'docs/architecture/review/evidence/plan04/phase7-reconciliation-status.json'
$diagrams = @(Get-ChildItem -LiteralPath (Repo 'docs/architecture/review/diagrams/plan04') -File -Filter '*.mmd')
$diagramResults = @($diagrams | ForEach-Object { $text = Get-Content -Raw -LiteralPath $_.FullName; [ordered]@{ file = $_.Name; nonEmpty = $text.Length -gt 80; mermaidSyntax = $text -match '^(flowchart|stateDiagram)' } })
$requiredSliceStatuses = @(0..7 | ForEach-Object { Get-ChildItem -LiteralPath (Repo 'docs/architecture/review/evidence/plan04') -File -Filter "phase$_*-status.json" })
$checks = [ordered]@{
    bilingualDesignsLinkEachOther = $zh -match 'module-boundary-evolution\.en\.md' -and $en -match 'module-boundary-evolution\.zh-CN\.md'
    designsCoverAllFourDecisionsAndClaimBoundary = @('GOV4','DP6','DB8','GOV3','PRE-READY','not-claimed' | Where-Object { $zh -notmatch $_ -or $en -notmatch $_ }).Count -eq 0
    exactRequiredDiagramSet = $diagrams.Count -eq 5 -and @($diagramResults | Where-Object { -not $_.nonEmpty -or -not $_.mermaidSyntax }).Count -eq 0
    ruleMapCoversEnforcementTestsOwnersAndGates = @($map.mappings).Count -ge 6 -and @($map.mappings | Where-Object { @($_.enforcement).Count -eq 0 -or @($_.behaviorEvidence).Count -eq 0 -or [string]::IsNullOrWhiteSpace([string]$_.owner) -or [string]::IsNullOrWhiteSpace([string]$_.gateHandback) }).Count -eq 0
    sliceEvidenceIndexIsComplete = $requiredSliceStatuses.Count -eq 8 -and (Test-Path -LiteralPath (Repo 'docs/architecture/review/evidence/plan04/README.md'))
    masterIndexAndTodoHaveUniquePlanLink = $master -match '04-module-boundary-evolution\.md' -and $planIndex -match '04-module-boundary-evolution\.md' -and $todo -match '04-module-boundary-evolution\.md'
    repositoryVerificationIsGreen = $phase7.result -eq 'repository-passed-functional-approvals-pending' -and $phase7.tests.totals.passed -eq 1108 -and $phase7.tests.totals.failed -eq 0
    approvalsTruthfullyRemainPending = $phase2.approvalComplete -eq $false -and $phase3.approvalComplete -eq $false -and $plan -match '- \[ \] ME2\.7' -and $plan -match '- \[ \] ME3\.8' -and $plan -match '- \[ \] ME8\.7'
    phaseAndProductionClaimsRemainOpen = $plan -match '- \[ \] \*\*Phase 8 完成' -and $plan -match 'RLS.*not-claimed|RLS.*未.*声明' -and $map.claimBoundary.productionReporting -eq 'not-claimed'
}
$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$status = [ordered]@{
    formatVersion = 1; plan = '04-module-boundary-evolution'; slice = 'P04-S8'; checkedAt = (Get-Date).ToString('yyyy-MM-dd')
    result = if ($failed.Count -eq 0) { 'documentation-passed-plan-pre-ready' } else { 'failed' }
    checks = $checks; diagrams = $diagramResults; ruleMappings = @($map.mappings).Count
    approvals = [ordered]@{ GOV4 = 'pending'; DP6 = 'pending'; finalPlanApproval = 'pending'; selfApproval = 'forbidden' }
    claims = $map.claimBoundary; failedChecks = $failed
}
$resolvedStatus = Repo $StatusPath
$status | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $resolvedStatus -Encoding utf8NoBOM
if ($failed.Count -gt 0) { throw "Plan 04 documentation validation failed: $($failed -join ', '). Report: $resolvedStatus" }
Write-Host "Plan 04 documentation result: $($status.result). Report: $resolvedStatus"
