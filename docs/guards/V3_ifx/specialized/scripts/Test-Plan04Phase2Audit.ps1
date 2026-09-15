[CmdletBinding()]
param(
    [string] $DecisionPath = 'docs/architecture/review/evidence/plan04/module-boundary-decisions.json',
    [string] $StatusPath = 'docs/architecture/review/evidence/plan04/phase2-audit-status.json',
    [switch] $RequireApproval
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
function Repo([string] $path) {
    if ([IO.Path]::IsPathRooted($path)) { return $path }
    return Join-Path $repositoryRoot $path
}
function Sha256([string] $path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath (Repo $path)).Hash.ToLowerInvariant()
}
function Has-Cycle([string[]] $nodes, [object[]] $edges) {
    $inDegree = @{}
    $adjacency = @{}
    foreach ($node in $nodes) { $inDegree[$node] = 0; $adjacency[$node] = @() }
    foreach ($edge in $edges) {
        if (-not $inDegree.ContainsKey([string]$edge.from) -or -not $inDegree.ContainsKey([string]$edge.to)) { return $true }
        $adjacency[[string]$edge.from] += [string]$edge.to
        $inDegree[[string]$edge.to]++
    }
    $queue = [Collections.Generic.Queue[string]]::new()
    foreach ($node in $nodes) { if ($inDegree[$node] -eq 0) { $queue.Enqueue($node) } }
    $visited = 0
    while ($queue.Count -gt 0) {
        $node = $queue.Dequeue(); $visited++
        foreach ($target in $adjacency[$node]) {
            $inDegree[$target]--
            if ($inDegree[$target] -eq 0) { $queue.Enqueue($target) }
        }
    }
    return $visited -ne $nodes.Count
}

$decision = Get-Content -Raw -LiteralPath (Repo $DecisionPath) | ConvertFrom-Json -Depth 100
$inventoryPath = 'docs/architecture/review/evidence/plan04/module-boundary-inventory.json'
$inventory = Get-Content -Raw -LiteralPath (Repo $inventoryPath) | ConvertFrom-Json -Depth 100
$plan = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/04-module-boundary-evolution.md')
$modules = @('auth','crm','registry','transaction','holdings')
$protocolEdges = @($inventory.protocolEdges | ForEach-Object { [pscustomobject]@{ from=$_.provider; to=$_.consumer; kind=$_.kind } })
$physicalEdges = @($inventory.projectEdges | Where-Object {
    $_.fromModule -in $modules -and $_.toModule -in $modules -and $_.fromModule -ne $_.toModule
} | ForEach-Object { [pscustomobject]@{ from=$_.fromModule; to=$_.toModule } })
$syncCycle = Has-Cycle $modules @($protocolEdges | Where-Object kind -eq 'sync')
$asyncCycle = Has-Cycle $modules @($protocolEdges | Where-Object kind -eq 'event')
$mixedCycle = Has-Cycle $modules $protocolEdges
$compileCycle = Has-Cycle $modules $physicalEdges
$allowed = @('retain','narrow-edge','revisit-boundary','extraction-candidate')
$requiredApprovals = @('architecture','auth-module','crm-module','registry-module','transaction-module','holdings-module')
$approvalComplete = @($decision.approvals).Count -eq $requiredApprovals.Count -and
    @(Compare-Object $requiredApprovals @($decision.approvals.role)).Count -eq 0 -and
    @($decision.approvals | Where-Object {
        $_.status -ne 'approved' -or [string]::IsNullOrWhiteSpace([string]$_.approver) -or [string]::IsNullOrWhiteSpace([string]$_.evidence)
    }).Count -eq 0

$checks = [ordered]@{
    decisionBoundToInventory = $decision.inventorySha256 -eq (Sha256 $inventoryPath)
    exactModuleConclusions = @(Compare-Object $modules @($decision.modules.module)).Count -eq 0 -and
        @($decision.modules | Where-Object { $_.conclusion -notin $allowed -or $_.conclusion -eq 'split-now' }).Count -eq 0
    conclusionsCarryEvidenceOwnerRiskAndTriggers = @($decision.modules | Where-Object {
        [string]::IsNullOrWhiteSpace($_.owner) -or @($_.evidence).Count -eq 0 -or @($_.risks).Count -eq 0 -or @($_.revisitTriggers).Count -eq 0
    }).Count -eq 0
    directionsMatchAuthoritativeProtocols = @($decision.directionReviews).Count -eq @($inventory.protocolEdges).Count -and
        @($decision.directionReviews | Where-Object {
            $review = $_
            @($inventory.protocolEdges | Where-Object {
                $_.identity -eq $review.identity -and $_.provider -eq $review.provider -and $_.consumer -eq $review.consumer -and $_.kind -eq $review.kind
            }).Count -ne 1 -or $review.decision -ne 'aligned'
        }).Count -eq 0
    cycleClaimsMatchComputedGraphs = -not $syncCycle -and -not $asyncCycle -and -not $mixedCycle -and -not $compileCycle -and
        @($decision.cycleReview.syncProtocolCycles).Count -eq 0 -and @($decision.cycleReview.asyncProtocolCycles).Count -eq 0 -and
        @($decision.cycleReview.mixedProtocolCycles).Count -eq 0 -and @($decision.cycleReview.compileReferenceCycles).Count -eq 0
    noUnregisteredOrCrossSchemaFindings = @($inventory.failClosedFindings.unregisteredCrossModuleProjectEdges).Count -eq 0 -and
        @($inventory.failClosedFindings.crossSchemaDataAccess).Count -eq 0
    revisitItemsMatchConclusions = @($decision.modules | Where-Object conclusion -eq 'revisit-boundary').Count -eq @($decision.revisitBoundaryItems).Count
    reviewTriggersCoverFutureDrift = @('protocol','cycle','owner','cross-schema','Contract','cochange','runtime' | Where-Object {
        $term = $_
        @($decision.reviewTriggers | Where-Object { $_ -match $term }).Count -eq 0
    }).Count -eq 0
    metricsCannotAuthorizeSplit = $decision.decisionPolicy.metricsUse -eq 'review-signals-only' -and
        $decision.decisionPolicy.defaultDeployment -eq 'modular-monolith' -and $decision.decisionPolicy.forbiddenConclusion -eq 'split-now'
    checklistTruthfullyLeavesApprovalOpen = $plan -match '- \[ \] \*\*Phase 2 完成' -and $plan -match '- \[ \] ME2\.7'
}

$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$repositoryPassed = $failed.Count -eq 0
$status = [ordered]@{
    formatVersion = 1
    plan = '04-module-boundary-evolution'
    slice = 'P04-S2'
    result = if (-not $repositoryPassed) { 'failed' } elseif ($approvalComplete) { 'passed' } else { 'repository-passed-approval-pending' }
    checkedAt = (Get-Date).ToString('yyyy-MM-dd')
    decisionsSha256 = Sha256 $DecisionPath
    checks = $checks
    graphCycles = [ordered]@{ sync=$syncCycle; async=$asyncCycle; mixed=$mixedCycle; compile=$compileCycle }
    conclusions = @($decision.modules | ForEach-Object { [ordered]@{ module=$_.module; conclusion=$_.conclusion; owner=$_.owner } })
    approvalComplete = $approvalComplete
    approvals = $decision.approvals
    gov4 = if ($approvalComplete) { 'closed' } else { 'approval-pending' }
    failedChecks = $failed
    productionClaims = [ordered]@{ microserviceSplit='not-claimed'; independentRelease='not-claimed' }
}
$resolvedStatus = Repo $StatusPath
$status | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $resolvedStatus -Encoding utf8NoBOM
if (-not $repositoryPassed) { throw "Plan 04 Phase 2 audit failed: $($failed -join ', '). Report: $resolvedStatus" }
if ($RequireApproval -and -not $approvalComplete) { throw "Plan 04 Phase 2 named approvals are pending. Report: $resolvedStatus" }
Write-Host "Plan 04 Phase 2 audit result: $($status.result). Report: $resolvedStatus"
