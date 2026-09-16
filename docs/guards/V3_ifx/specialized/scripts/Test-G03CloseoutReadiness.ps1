[CmdletBinding()]
param(
    [string] $ReportPath = 'docs/architecture/review/evidence/gates/G03/G03-phase9-status.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = if ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..')) }
$resolvedReportPath = if ([IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $repositoryRoot $ReportPath }
$catalog = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/architecture/review/gates/G03/contract-event-catalog.yaml') | ConvertFrom-Json -Depth 100
$g03Plan = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/architecture/review/plans/00-G03-contract-event-governance.md')
$layerGuardPlan = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/architecture/review/plans/03-layerguard-alignment.md')
$today = (Get-Date).Date
$blockers = [Collections.Generic.List[object]]::new()
function Add-Blocker([string] $Code, [string] $Owner, [string] $Revisit, [string] $Evidence) {
    $blockers.Add([ordered]@{ code = $Code; owner = $Owner; revisitWhen = $Revisit; currentEvidence = $Evidence })
}

if ([string]::IsNullOrWhiteSpace($catalog.approvalPolicy.backupOwner)) {
    Add-Blocker 'backup-owner-unassigned' 'repository-maintainer' 'before first Proposed-to-Active transition or Gate closure' 'approvalPolicy.backupOwner is null'
}
$proposed = @($catalog.protocols | Where-Object lifecycle -ne 'Active')
if ($proposed.Count -gt 0) {
    Add-Blocker 'protocols-not-active' 'Plans 01/02 provider and consumer owners' 'after physical V1 source, snapshots, behavior tests, reconciliation, and approvals' (($proposed.identity | Sort-Object) -join ', ')
}
if ($g03Plan -match '- \[ \] G03-6\.5' -or $g03Plan -match '- \[ \] G03-6\.6') {
    Add-Blocker 'behavior-tests-pending' 'Plans 01/02 implementers' 'when real provider Contracts and consumer Adapters exist' 'G03-6.5 and G03-6.6 remain open'
}
$messagingContracts = Join-Path $repositoryRoot 'src/Platform/Messaging/IFX.Platform.Messaging.Contracts/IFX.Platform.Messaging.Contracts.csproj'
$messagingRuntime = Join-Path $repositoryRoot 'src/Platform/Messaging/IFX.Platform.Messaging.Runtime/IFX.Platform.Messaging.Runtime.csproj'
if (-not (Test-Path -LiteralPath $messagingContracts) -or -not (Test-Path -LiteralPath $messagingRuntime)) {
    Add-Blocker 'messaging-contract-runtime-split-pending' 'Plan 02 Platform Messaging owner' 'when the BCL-only Contracts and runtime projects are created and dependency-tested' 'one or both target projects are absent'
}
if ($layerGuardPlan -match '- \[ \] L5\.1') {
    Add-Blocker 'layerguard-direct-consumption-pending' 'Plan 03 L5.1 owner' 'when Gate policy binding starts' 'generated handoff exists; L5.1 direct consumption is open'
}
if ($g03Plan -match '- \[ \] G03-9\.8') {
    Add-Blocker 'closure-approvals-pending' 'module, consumer, Platform Messaging, and architecture owners' 'after all technical blockers are cleared' 'G03-9.8 remains open'
}

$overdue = @($catalog.publicSurface | Where-Object { $_.lifecycle -eq 'LegacyPendingMigration' -and [DateTime]$_.expiresAt -lt $today })
$handoffPaths = @(
    'docs/architecture/review/gates/G03/handoffs/plan01-contracts-handoff.md'
    'docs/architecture/review/gates/G03/handoffs/plan02-events-handoff.md'
    'docs/architecture/review/gates/G03/handoffs/plan03-layerguard-handoff.md'
)
$missingHandoffs = @($handoffPaths | Where-Object { -not (Test-Path -LiteralPath (Join-Path $repositoryRoot $_)) })
$closeoutPath = 'docs/architecture/review/evidence/gates/G03/G03-closeout.md'
$closeoutDocuments = @($handoffPaths) + $closeoutPath
$brokenLinks = [Collections.Generic.List[string]]::new()
foreach ($relativeDocument in $closeoutDocuments) {
    $document = Join-Path $repositoryRoot $relativeDocument
    if (-not (Test-Path -LiteralPath $document)) { continue }
    $content = Get-Content -Raw -LiteralPath $document
    foreach ($match in [regex]::Matches($content, '!?' + '\[[^\]]*\]\((?<target>[^)]+)\)')) {
        $target = $match.Groups['target'].Value.Split('#')[0]
        if ([string]::IsNullOrWhiteSpace($target) -or $target -match '^(https?://|mailto:|#)') { continue }
        $resolved = Join-Path (Split-Path -Parent $document) $target.Trim('<', '>')
        if ([IO.Path]::GetFullPath($resolved) -eq [IO.Path]::GetFullPath($resolvedReportPath)) { continue }
        if (-not (Test-Path -LiteralPath $resolved)) { $brokenLinks.Add("${relativeDocument}:$target") }
    }
}
$checks = [ordered]@{
    allLegacyItemsHaveDisposition = @($catalog.publicSurface | Where-Object { [string]::IsNullOrWhiteSpace($_.disposition) }).Count -eq 0
    noLegacyDeadlineExceeded = $overdue.Count -eq 0
    downstreamHandoffPackagesPresent = $missingHandoffs.Count -eq 0
    closeoutDocumentPresent = Test-Path -LiteralPath (Join-Path $repositoryRoot $closeoutPath)
    closeoutLinksResolve = $brokenLinks.Count -eq 0
    blockersCarryOwnerAndRevisit = @($blockers | Where-Object { [string]::IsNullOrWhiteSpace($_.owner) -or [string]::IsNullOrWhiteSpace($_.revisitWhen) }).Count -eq 0
}
$report = [ordered]@{
    formatVersion = 1
    gate = 'G03'
    phase = 9
    result = if ($checks.Values -contains $false) { 'failed' } else { 'passed' }
    closureStatus = if ($blockers.Count -eq 0) { 'ready-for-approval' } else { 'pre-ready' }
    readyForClosure = $blockers.Count -eq 0
    checkedAt = $today.ToString('yyyy-MM-dd')
    checks = $checks
    counts = [ordered]@{
        protocols = @($catalog.protocols).Count
        activeProtocols = @($catalog.protocols | Where-Object lifecycle -eq 'Active').Count
        legacyItems = @($catalog.publicSurface).Count
        overdueLegacyItems = $overdue.Count
        blockers = $blockers.Count
    }
    blockers = $blockers
    missingHandoffs = $missingHandoffs
    brokenLinks = $brokenLinks
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedReportPath -Encoding utf8NoBOM
if ($report.result -ne 'passed') { throw "G03 closeout readiness audit failed. Report: $resolvedReportPath" }
Write-Host "G03 closeout readiness audit passed with status '$($report.closureStatus)'. Report: $resolvedReportPath"
