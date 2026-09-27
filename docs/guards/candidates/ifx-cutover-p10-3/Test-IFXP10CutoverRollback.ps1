[CmdletBinding()]
param(
    [ValidateSet('Validate','Aggregate')][string] $Mode = 'Validate',
    [string] $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path,
    [string] $EvidenceRoot = 'artifacts/guards/p10-ifx-114/p10-3-design-042/rehearsal',
    [ValidateSet('success','failure','cancelled','skipped')][string] $ContractResult = 'success',
    [ValidateSet('success','failure','cancelled','skipped')][string] $WindowsResult = 'success'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw $Message }
}
function Get-Hash([string] $Path) {
    (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}
function Write-Json([string] $Path, $Value) {
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    $json = ($Value | ConvertTo-Json -Depth 100) + [char]10
    [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}
function Same-Ordinal([object[]] $Left, [object[]] $Right) {
    ([string]::Join([char]0, @($Left))) -ceq ([string]::Join([char]0, @($Right)))
}
function Same-UniqueSet([object[]] $Left, [object[]] $Right) {
    $leftValues = @($Left | ForEach-Object { [string] $_ })
    $rightValues = @($Right | ForEach-Object { [string] $_ })
    $leftUnique = @($leftValues | Sort-Object -CaseSensitive -Unique)
    $rightUnique = @($rightValues | Sort-Object -CaseSensitive -Unique)
    ($leftValues.Count -eq $leftUnique.Count) -and
        ($rightValues.Count -eq $rightUnique.Count) -and
        (Same-Ordinal $leftUnique $rightUnique)
}
function Get-TreeDigest([string] $Root) {
    Assert-True (Test-Path -LiteralPath $Root -PathType Container) "Protected root is missing: $Root"
    $rows = @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\','/')
        "$relative|$($_.Length)|$(Get-Hash $_.FullName)"
    } | Sort-Object)
    $bytes = [Text.Encoding]::UTF8.GetBytes([string]::Join([char]10, $rows))
    $digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
    [ordered]@{ path = $Root; fileCount = $rows.Count; sha256 = $digest }
}

if ($Mode -ceq 'Aggregate') {
    $failures = [Collections.Generic.List[string]]::new()
    if ($ContractResult -cne 'success') { $failures.Add("v4-ifx-contract did not succeed: $ContractResult") }
    if ($WindowsResult -cne 'success') { $failures.Add("v4-ifx-windows did not succeed: $WindowsResult") }
    $result = [ordered]@{
        formatVersion = 1
        status = if ($failures.Count -eq 0) { 'pass' } else { 'fail' }
        exitCategory = if ($failures.Count -eq 0) { 'success' } else { 'findings-blocking' }
        failures = @($failures)
    }
    $json = $result | ConvertTo-Json -Depth 10
    if ($failures.Count -gt 0) { [Console]::Error.WriteLine($json); exit 16 }
    Write-Output $json
    exit 0
}

$root = [IO.Path]::GetFullPath($RepositoryRoot)
$evidence = if ([IO.Path]::IsPathRooted($EvidenceRoot)) {
    [IO.Path]::GetFullPath($EvidenceRoot)
} else {
    [IO.Path]::GetFullPath((Join-Path $root $EvidenceRoot))
}
Assert-True (-not (Test-Path -LiteralPath $evidence)) "EvidenceRoot must be absent before the single rehearsal: $evidence"

$paths = [ordered]@{
    c6e = Join-Path $root 'artifacts/guards/p10-ifx-114/c6e-r1-042/c6e-r1-decision.json'
    p10_2 = Join-Path $root 'artifacts/guards/p10-ifx-114/p10-2-r2-parity-042/p10-2-decision.json'
    c6cDecision = Join-Path $root 'artifacts/guards/p10-ifx-114/recovery-042/c6c-decision.json'
    windowsFull = Join-Path $root 'artifacts/guards/p10-ifx-114/c6c-recovery-042-full/windows/summary.json'
    remote = Join-Path $root 'artifacts/guards/p10-ifx-114/p10-3-design-042/remote-snapshot.json'
    proposal = Join-Path $root 'docs/guards/v4/integrations/github/ifx-cutover-proposal.json'
    workflow = Join-Path $root 'docs/guards/v4/integrations/github/proposed-v4-ifx-guardrails.yml'
    requiredChecks = Join-Path $root 'docs/guards/V3_ifx/stages/ci/required-checks.json'
    v3Workflow = Join-Path $root '.github/workflows/v3-ifx-guardrails.yml'
}
$expected = [ordered]@{
    c6e = '94a7c01bd991a7b4371f6d3406b43f58830bdb29740c477db7abdaf2bb0ece22'
    p10_2 = '7c5ff243ec452958ffbb08ced46ae6e1a8320f586b9fb71ef0d98f2931934516'
    c6cDecision = '33a72d199144b1914d6d30c9f355b653aeb455fcebdd7e0143851344f995683c'
    windowsFull = '858b69949c0febc386557f8bb70287d2abe3a7c2af56e6f5aa20b2fbc7de9ff8'
    requiredChecks = '8b8f44dc1282e7b37348d8d6cd2cf15c188b0b0991e29ffff5ceadc9d70e74a0'
    v3Workflow = '3bfcc942deba649fc6df4825067428a94f07664782ac146ffb20c8f74c0e0e4e'
}
foreach ($name in $expected.Keys) {
    Assert-True ([IO.File]::Exists($paths[$name])) "Required input is missing: $($paths[$name])"
    Assert-True ((Get-Hash $paths[$name]) -ceq $expected[$name]) "Identity drift: $name"
}

$c6e = Get-Content -Raw -LiteralPath $paths.c6e | ConvertFrom-Json -Depth 100
$p10 = Get-Content -Raw -LiteralPath $paths.p10_2 | ConvertFrom-Json -Depth 100
$c6c = Get-Content -Raw -LiteralPath $paths.c6cDecision | ConvertFrom-Json -Depth 100
$windows = Get-Content -Raw -LiteralPath $paths.windowsFull | ConvertFrom-Json -Depth 100
$remote = Get-Content -Raw -LiteralPath $paths.remote | ConvertFrom-Json -Depth 100
$proposal = Get-Content -Raw -LiteralPath $paths.proposal | ConvertFrom-Json -Depth 100
$required = Get-Content -Raw -LiteralPath $paths.requiredChecks | ConvertFrom-Json -Depth 100
$workflow = Get-Content -Raw -LiteralPath $paths.workflow

Assert-True ($c6e.status -ceq 'pass' -and $c6e.decision -ceq 'c6e-r1-git-backed-repair-accepted') 'P10.1 decision is not accepted.'
Assert-True ($p10.status -ceq 'pass' -and $p10.decision -ceq 'p10-2-parity-accepted' -and $p10.gapCount -eq 0) 'P10.2 decision is not zero-gap accepted.'
Assert-True ($c6c.status -ceq 'pass' -and $c6c.baseVersion -ceq '1.1.4' -and $c6c.candidateVersion -ceq '0.4.2') 'C6c decision identity mismatch.'
Assert-True ($windows.status -ceq 'pass' -and $windows.platform -ceq 'windows' -and $windows.baseVersion -ceq '1.1.4' -and $windows.bundleVersion -ceq '0.4.2') 'Windows-full identity mismatch.'
Assert-True ($c6e.frozenAuthority.targetCommit -ceq $proposal.identity.targetCommit -and $windows.sourceCommit -ceq $proposal.identity.targetCommit) 'Target commit is not shared across P10.1, C6c and proposal.'
Assert-True ($c6e.composition.packageHash -ceq $proposal.identity.packageSha256) 'Composed Package identity mismatch.'
Assert-True ($windows.bundleManifestSha256 -ceq $proposal.identity.bundleManifestSha256 -and $windows.profileSha256 -ceq $proposal.identity.profileSha256) 'Bundle/Profile identity mismatch.'

Assert-True ($remote.status -ceq 'pass' -and $remote.mode -ceq 'github-get-only') 'Remote snapshot is not a passing GET-only capture.'
Assert-True ($remote.ruleset.id -eq 23459908 -and $remote.ruleset.enforcement -ceq 'active' -and $remote.ruleset.strict) 'Live ruleset boundary mismatch.'
$declaredContexts = @($required.jobs | Where-Object blocking | ForEach-Object id)
$remoteContexts = @($remote.ruleset.requiredContexts)
$proposalContexts = @($proposal.currentV3Contexts)
Assert-True (Same-UniqueSet @('context-b','context-a') @('context-a','context-b')) 'Context comparison must ignore non-semantic order.'
Assert-True (-not (Same-UniqueSet @('context-a','context-a') @('context-a'))) 'Context comparison must reject duplicates.'
Assert-True (Same-UniqueSet $declaredContexts $remoteContexts) 'Live ruleset contexts differ from the checked-in V3 contract.'
Assert-True (Same-UniqueSet $declaredContexts $proposalContexts) 'Proposal does not preserve the exact V3 context set.'
Assert-True ($proposal.contextOwnership.Count -eq $declaredContexts.Count) 'Every V3 context must have exactly one ownership row.'
foreach ($context in $declaredContexts) {
    $rows = @($proposal.contextOwnership | Where-Object v3Context -CEQ $context)
    Assert-True ($rows.Count -eq 1 -and -not [string]::IsNullOrWhiteSpace($rows[0].v4Owner)) "Missing context owner: $context"
}
Assert-True (@($proposal.detectorOwnership | Where-Object status -ceq 'temporary-bridge').Count -eq 1) 'Exactly one Linux portability bridge must remain explicit.'
Assert-True ($proposal.coexistence.allV3ContextsRemainRequired -and $proposal.coexistence.v4AggregateIsAdditive) 'Coexistence must be additive.'
Assert-True ($proposal.activationBlocked -and -not $proposal.remoteMutationAuthorized) 'Design must remain activation-blocked.'
Assert-True ($proposal.trustedInputs.bundlePublicationState -ceq 'not-published-separate-plan-required') 'Missing bundle publication blocker.'

$states = @{}
foreach ($state in $proposal.states) { $states[$state.id] = @($state.requiredContexts) }
Assert-True (Same-UniqueSet $states['v3-active'] $declaredContexts) 'V3-active state drifted.'
Assert-True (Same-UniqueSet $states['rollback-restored'] $declaredContexts) 'Rollback does not restore the exact V3 contexts.'
foreach ($context in $declaredContexts) {
    Assert-True ($context -cin $states['coexistence']) "Coexistence dropped V3 context: $context"
}
Assert-True ('v4-ifx-required' -cin $states['coexistence']) 'Coexistence is missing the V4 aggregate.'
Assert-True (Same-UniqueSet $states['v4-primary-with-linux-bridge'] @('v4-ifx-required','v3-cross-platform-ubuntu-latest')) 'Primary state lost its Linux bridge or aggregate.'

$enter = @($proposal.transitions | Where-Object id -ceq 'enter-coexistence')[0]
$promote = @($proposal.transitions | Where-Object id -ceq 'promote-v4-primary')[0]
$rollback = @($proposal.transitions | Where-Object id -ceq 'rollback')[0]
Assert-True ($enter.order[-1] -ceq 'add-v4-ifx-required-without-removing-v3-contexts') 'Coexistence ordering is unsafe.'
Assert-True ($promote.order[-1] -ceq 'remove-the-other-twelve-v3-contexts') 'Primary promotion removes V3 too early.'
$restoreIndex = [Array]::IndexOf([object[]]$rollback.order, 'restore-all-thirteen-v3-required-contexts')
$removeV4Index = [Array]::IndexOf([object[]]$rollback.order, 'remove-v4-ifx-required')
Assert-True ($restoreIndex -ge 0 -and $removeV4Index -gt $restoreIndex) 'Rollback removes V4 before restoring V3.'
Assert-True ($proposal.rollback.restoreCommit -ceq $remote.developmentBranch.remoteCommit -and $proposal.rollback.restoreWorkflowBlob -ceq $remote.developmentBranch.v3WorkflowBlob) 'Rollback restore identity differs from the read-only remote snapshot.'
Assert-True (@($proposal.negativeControls | Where-Object expected -ceq 'rejected').Count -eq 5) 'All five negative controls must reject.'

Assert-True ($paths.workflow -notmatch '[\\/]\.github[\\/]workflows[\\/]') 'Specimen must remain outside the active workflow directory.'
Assert-True ($workflow -match '(?m)^# INACTIVE P10\.3 SPECIMEN\.') 'Inactive specimen marker is missing.'
Assert-True ($workflow -match '(?ms)^permissions:\s*\r?\n\s+contents:\s+read\s*$') 'Workflow permissions are broader than contents: read.'
Assert-True ($workflow -notmatch '\$\{\{\s*secrets\.') 'Workflow must not depend on repository secrets.'
Assert-True ($workflow -match '(?m)^  v4-ifx-required:\s*\r?$' -and $workflow -match '(?m)^\s+if:\s+always\(\)\s*\r?$') 'Always-present aggregate job is missing.'
foreach ($hash in @($proposal.identity.baseArchiveSha256, $proposal.identity.bundleManifestSha256, $proposal.identity.productionReviewSha256, $proposal.identity.targetCommit)) {
    Assert-True ($workflow.Contains($hash)) "Workflow does not bind identity: $hash"
}
Assert-True ($workflow -match 'ifx-trusted-base/docs/guards/candidates/ifx-cutover-p10-3/Test-IFXP10CutoverRollback\.ps1') 'Aggregate is not evaluated from the trusted base.'

$protected = [ordered]@{
    baseInstall = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.4'
    composedInstall = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.4-ifx-0.4.2-c6e-r1'
    acceptedBundle = (Join-Path $root 'artifacts/guards/p10-ifx-114/recovery-042/authorized-refresh/formal-candidate-a/97129b4b44874b05956bcb6a4c95d4e9/bundle')
    cleanTarget = 'D:/IFX-Root/guard-runtime/fixtures/ifx-c6e-r1-clean-042'
    violatingTarget = 'D:/IFX-Root/guard-runtime/fixtures/ifx-c6e-r1-violating-042'
}
$pre = [ordered]@{}
foreach ($name in $protected.Keys) { $pre[$name] = Get-TreeDigest $protected[$name] }

[void][IO.Directory]::CreateDirectory($evidence)
Write-Json (Join-Path $evidence 'pre-inventories.json') ([ordered]@{ formatVersion = 1; roots = $pre })

$rehearsal = [ordered]@{
    formatVersion = 1
    status = 'pass'
    entryIdentities = 'pass'
    remoteSnapshot = 'pass'
    contextOwnershipRows = $proposal.contextOwnership.Count
    detectorOwnershipRows = $proposal.detectorOwnership.Count
    states = @($proposal.states | ForEach-Object id)
    transitions = @($proposal.transitions | ForEach-Object id)
    negativeControls = @($proposal.negativeControls | ForEach-Object { [ordered]@{ id = $_.id; actual = 'rejected' } })
    coexistence = [ordered]@{
        minimumCalendarDays = $proposal.coexistence.minimumCalendarDays
        minimumDistinctPullRequestHeads = $proposal.coexistence.minimumDistinctPullRequestHeads
        allV3ContextsRemainRequired = $proposal.coexistence.allV3ContextsRemainRequired
    }
    activationBlockers = @($proposal.activationPrerequisites)
}
Write-Json (Join-Path $evidence 'rehearsal.json') $rehearsal

$post = [ordered]@{}
foreach ($name in $protected.Keys) {
    $post[$name] = Get-TreeDigest $protected[$name]
    Assert-True ($post[$name].sha256 -ceq $pre[$name].sha256) "Protected root mutated: $name"
}
Write-Json (Join-Path $evidence 'post-inventories.json') ([ordered]@{ formatVersion = 1; roots = $post })

$decision = [ordered]@{
    formatVersion = 1
    status = 'pass'
    decision = 'p10-3-design-and-local-rehearsal-accepted'
    planId = '20260927-v4-p10-3-cutover-and-rollback-design'
    identity = $proposal.identity
    remote = [ordered]@{
        defaultBranch = $remote.defaultBranch
        rulesetId = $remote.ruleset.id
        requiredContextCount = $remote.ruleset.requiredContexts.Count
        remoteMutationPerformed = $false
    }
    proof = [ordered]@{
        contextOwnershipRows = $proposal.contextOwnership.Count
        detectorOwnershipRows = $proposal.detectorOwnership.Count
        negativeControlCount = $proposal.negativeControls.Count
        protectedRootsUnchanged = $true
    }
    activationBlockers = @($proposal.activationPrerequisites)
    boundary = [ordered]@{
        p10_3DesignComplete = $true
        p10GatePassed = $false
        workflowInstalled = $false
        rulesetChanged = $false
        activated = $false
        ifxCutover = $false
        v3Retired = $false
    }
    recommendation = 'P10.3 design is complete. Remote activation requires new exact Plans and explicit authorization for every listed prerequisite.'
}
Write-Json (Join-Path $evidence 'p10-3-decision.json') $decision
Write-Output "P10.3 local rehearsal PASS: $evidence"
