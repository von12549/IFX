# V4-TODO-008 T7 (Plan 20260928-v4-todo-008-t7-ifx-consumer-rebinding) step R7: P10.3 successor
# rehearsal for V4 Guards 1.1.5 from von12549/Guard + ifx-profile-candidate 0.4.3.
# It re-proves the accepted P10.3 design rules (docs/guards/candidates/ifx-cutover-p10-3/
# Test-IFXP10CutoverRollback.ps1, unchanged) against the successor proposal and specimen, and adds
# executed negative controls: each mutated proposal/specimen copy must be rejected by the same checks.
# Aggregate mode is the future trusted-base aggregate of the inactive specimen.
[CmdletBinding()]
param(
    [ValidateSet('Validate','Aggregate')][string] $Mode = 'Validate',
    [string] $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path,
    [string] $IdentityPath = 'docs/guards/candidates/ifx-rebind-115/t7-identity.json',
    [string] $EvidenceRoot = 'artifacts/guards/p10-ifx-115/p10-3-successor-043/rehearsal',
    [ValidateSet('success','failure','cancelled','skipped')][string] $ContractResult = 'success',
    [ValidateSet('success','failure','cancelled','skipped')][string] $WindowsResult = 'success'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }
function Get-Hash([string] $Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Write-Json([string] $Path, $Value) {
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
}
function Same-Ordinal([object[]] $Left, [object[]] $Right) { ([string]::Join([char]0, @($Left))) -ceq ([string]::Join([char]0, @($Right))) }
function Same-UniqueSet([object[]] $Left, [object[]] $Right) {
    $l = @($Left | ForEach-Object { [string] $_ }); $r = @($Right | ForEach-Object { [string] $_ })
    $lu = @($l | Sort-Object -CaseSensitive -Unique); $ru = @($r | Sort-Object -CaseSensitive -Unique)
    ($l.Count -eq $lu.Count) -and ($r.Count -eq $ru.Count) -and (Same-Ordinal $lu $ru)
}
function Get-TreeDigest([string] $Root) {
    Assert-True (Test-Path -LiteralPath $Root -PathType Container) "Protected root is missing: $Root"
    $rows = @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | ForEach-Object {
        "$([IO.Path]::GetRelativePath($Root, $_.FullName).Replace('\','/'))|$($_.Length)|$(Get-Hash $_.FullName)"
    } | Sort-Object)
    [ordered]@{ path = $Root; fileCount = $rows.Count; sha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]::Join([char]10, $rows)))).ToLowerInvariant() }
}
function Get-EnvValue([string] $Workflow, [string] $Name) {
    $m = [regex]::Match($Workflow, "(?m)^  $([regex]::Escape($Name)):\s*(\S+)\s*\r?$")
    if ($m.Success) { $m.Groups[1].Value } else { $null }
}

if ($Mode -ceq 'Aggregate') {
    $failures = [Collections.Generic.List[string]]::new()
    if ($ContractResult -cne 'success') { $failures.Add("v4-ifx-contract did not succeed: $ContractResult") }
    if ($WindowsResult -cne 'success') { $failures.Add("v4-ifx-windows did not succeed: $WindowsResult") }
    $result = [ordered]@{ formatVersion = 1; status = $(if ($failures.Count -eq 0) { 'pass' } else { 'fail' }); exitCategory = $(if ($failures.Count -eq 0) { 'success' } else { 'findings-blocking' }); failures = @($failures) }
    $json = $result | ConvertTo-Json -Depth 10
    if ($failures.Count -gt 0) { [Console]::Error.WriteLine($json); exit 16 }
    Write-Output $json
    exit 0
}

$root = [IO.Path]::GetFullPath($RepositoryRoot)
function Full([string] $Path) { if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) } }
$evidence = Full $EvidenceRoot
Assert-True (-not (Test-Path -LiteralPath $evidence)) "EvidenceRoot must be absent before the single rehearsal: $evidence"
$identity = Get-Content -Raw -LiteralPath (Full $IdentityPath) | ConvertFrom-Json -AsHashtable -Depth 100

# Entry identities: every T7 record must match the committed identity file.
foreach ($name in @('c6cDecision','windowsFull','r4Decision','r5Decision','p10_2Decision','remoteSnapshot')) {
    $entry = $identity.records[$name]
    Assert-True ($null -ne $entry) "Identity file lacks record: $name"
    $path = Full ([string]$entry.path)
    Assert-True ([IO.File]::Exists($path)) "Required input is missing: $path"
    Assert-True ((Get-Hash $path) -ceq [string]$entry.sha256) "Identity drift: $name"
}
$paths = [ordered]@{
    proposal = Full 'docs/guards/v4-adoption/integrations/github/ifx-cutover-proposal.json'
    workflow = Full 'docs/guards/v4-adoption/integrations/github/proposed-v4-ifx-guardrails.yml'
    requiredChecks = Full 'docs/guards/V3_ifx/stages/ci/required-checks.json'
    v3Workflow = Full '.github/workflows/v3-ifx-guardrails.yml'
}
Assert-True ((Get-Hash $paths.requiredChecks) -ceq '8b8f44dc1282e7b37348d8d6cd2cf15c188b0b0991e29ffff5ceadc9d70e74a0') 'Identity drift: V3 required checks'
Assert-True ((Get-Hash $paths.v3Workflow) -ceq '3bfcc942deba649fc6df4825067428a94f07664782ac146ffb20c8f74c0e0e4e') 'Identity drift: V3 workflow'

$c6c = Get-Content -Raw -LiteralPath (Full $identity.records.c6cDecision.path) | ConvertFrom-Json -Depth 100
$windows = Get-Content -Raw -LiteralPath (Full $identity.records.windowsFull.path) | ConvertFrom-Json -Depth 100
$r4 = Get-Content -Raw -LiteralPath (Full $identity.records.r4Decision.path) | ConvertFrom-Json -Depth 100
$r5 = Get-Content -Raw -LiteralPath (Full $identity.records.r5Decision.path) | ConvertFrom-Json -Depth 100
$p10 = Get-Content -Raw -LiteralPath (Full $identity.records.p10_2Decision.path) | ConvertFrom-Json -Depth 100
$remote = Get-Content -Raw -LiteralPath (Full $identity.records.remoteSnapshot.path) | ConvertFrom-Json -Depth 100
$required = Get-Content -Raw -LiteralPath $paths.requiredChecks | ConvertFrom-Json -Depth 100
$releaseAssets = @($remote.guardRelease.assets)

Assert-True ($c6c.status -ceq 'pass' -and $c6c.baseVersion -ceq '1.1.5' -and $c6c.candidateVersion -ceq '0.4.3') 'C6c decision identity mismatch.'
Assert-True ($windows.status -ceq 'pass' -and $windows.platform -ceq 'windows' -and $windows.baseVersion -ceq '1.1.5' -and $windows.bundleVersion -ceq '0.4.3') 'Windows-full identity mismatch.'
Assert-True ($r4.status -ceq 'pass' -and $r4.decision -ceq 'c6d-exact-bundle-human-review-accepted') 'R4 human review is not accepted.'
Assert-True ($r5.status -ceq 'pass' -and $r5.decision -ceq 't7-r5-composition-accepted') 'R5 composition is not accepted.'
Assert-True ($p10.status -ceq 'pass' -and $p10.decision -ceq 'p10-2-parity-accepted' -and $p10.gapCount -eq 0) 'R6 parity is not zero-gap accepted.'
Assert-True ($remote.status -ceq 'pass' -and $remote.mode -ceq 'github-get-only') 'Remote snapshot is not a passing GET-only capture.'
Assert-True ($remote.ruleset.id -eq 23459908 -and $remote.ruleset.enforcement -ceq 'active' -and $remote.ruleset.strict) 'Live IFX ruleset boundary mismatch.'

function Test-Design($Proposal, [string] $Workflow, [bool] $CoreSourcePresent, $CleanupReceipt) {
    # Accepted P10.3 rules (unchanged semantics).
    $declared = @($required.jobs | Where-Object blocking | ForEach-Object id)
    Assert-True ($Proposal.identity.targetCommit -ceq $c6c.targetCommit -and $windows.sourceCommit -ceq $Proposal.identity.targetCommit -and $r5.targetCommit -ceq $Proposal.identity.targetCommit) 'Target commit is not shared across C6c, R5 and proposal.'
    Assert-True ($r5.composition.packageHash -ceq $Proposal.identity.packageSha256) 'Composed Package identity mismatch.'
    Assert-True ($windows.bundleManifestSha256 -ceq $Proposal.identity.bundleManifestSha256 -and $windows.profileSha256 -ceq $Proposal.identity.profileSha256) 'Bundle/Profile identity mismatch.'
    Assert-True (Same-UniqueSet $declared @($remote.ruleset.requiredContexts)) 'Live ruleset contexts differ from the checked-in V3 contract.'
    Assert-True (Same-UniqueSet $declared @($Proposal.currentV3Contexts)) 'Proposal does not preserve the exact V3 context set.'
    Assert-True (@($Proposal.contextOwnership).Count -eq $declared.Count) 'Every V3 context must have exactly one ownership row.'
    foreach ($context in $declared) {
        $rows = @($Proposal.contextOwnership | Where-Object v3Context -CEQ $context)
        Assert-True ($rows.Count -eq 1 -and -not [string]::IsNullOrWhiteSpace($rows[0].v4Owner)) "Missing context owner: $context"
    }
    Assert-True (@($Proposal.detectorOwnership | Where-Object status -ceq 'temporary-bridge').Count -eq 1) 'Exactly one Linux portability bridge must remain explicit.'
    Assert-True ($Proposal.coexistence.allV3ContextsRemainRequired -and $Proposal.coexistence.v4AggregateIsAdditive) 'Coexistence must be additive.'
    Assert-True ($Proposal.activationBlocked -and -not $Proposal.remoteMutationAuthorized) 'Design must remain activation-blocked.'
    Assert-True ($Proposal.trustedInputs.bundlePublicationState -ceq 'not-published-separate-plan-required') 'Missing bundle publication blocker.'
    $states = @{}; foreach ($state in $Proposal.states) { $states[$state.id] = @($state.requiredContexts) }
    Assert-True (Same-UniqueSet $states['v3-active'] $declared) 'V3-active state drifted.'
    Assert-True (Same-UniqueSet $states['rollback-restored'] $declared) 'Rollback does not restore the exact V3 contexts.'
    foreach ($context in $declared) { Assert-True ($context -cin $states['coexistence']) "Coexistence dropped V3 context: $context" }
    Assert-True ('v4-ifx-required' -cin $states['coexistence']) 'Coexistence is missing the V4 aggregate.'
    Assert-True (Same-UniqueSet $states['v4-primary-with-linux-bridge'] @('v4-ifx-required','v3-cross-platform-ubuntu-latest')) 'Primary state lost its Linux bridge or aggregate.'
    $rollback = @($Proposal.transitions | Where-Object id -ceq 'rollback')[0]
    $restoreIndex = [Array]::IndexOf([object[]]$rollback.order, 'restore-all-thirteen-v3-required-contexts')
    $removeV4Index = [Array]::IndexOf([object[]]$rollback.order, 'remove-v4-ifx-required')
    Assert-True ($restoreIndex -ge 0 -and $removeV4Index -gt $restoreIndex) 'Rollback removes V4 before restoring V3.'
    Assert-True ($Proposal.rollback.restoreCommit -ceq $remote.developmentBranch.remoteCommit -and $Proposal.rollback.restoreWorkflowBlob -ceq $remote.developmentBranch.v3WorkflowBlob) 'Rollback restore identity differs from the read-only remote snapshot.'
    Assert-True ($Workflow -match '(?m)^# INACTIVE P10\.3 SUCCESSOR SPECIMEN\.') 'Inactive specimen marker is missing.'
    Assert-True ($Workflow -match '(?ms)^permissions:\s*\r?\n\s+contents:\s+read\s*$') 'Workflow permissions are broader than contents: read.'
    Assert-True ($Workflow -notmatch '\$\{\{\s*secrets\.') 'Workflow must not depend on repository secrets.'
    Assert-True ($Workflow -match '(?m)^  v4-ifx-required:\s*\r?$' -and $Workflow -match '(?m)^\s+if:\s+always\(\)\s*\r?$') 'Always-present aggregate job is missing.'
    foreach ($hash in @($Proposal.identity.baseArchiveSha256, $Proposal.identity.bundleManifestSha256, $Proposal.identity.productionReviewSha256, $Proposal.identity.targetCommit)) {
        Assert-True ($Workflow.Contains([string]$hash)) "Workflow does not bind identity: $hash"
    }
    # Candidate self-judgment: the aggregate runs only from the previously trusted base.
    Assert-True ($Workflow -match 'pwsh -NoProfile -File "\$env:RUNNER_TEMP/ifx-trusted-base/docs/guards/candidates/ifx-rebind-115/Test-IFX115CutoverRollback\.ps1" -Mode Aggregate') 'Aggregate is not evaluated from the trusted base.'
    Assert-True ($Workflow -match 'git worktree add --detach "\$env:RUNNER_TEMP/ifx-trusted-base" \$env:BASE_SHA') 'Trusted base is not materialized from the PR base commit.'
    # Standalone release source: explicit Guard repository, exact tag, asset and digest.
    Assert-True ($Proposal.trustedInputs.baseReleaseRepository -ceq 'von12549/Guard' -and $Proposal.trustedInputs.baseReleaseTag -ceq 'v4-guards-v1.1.5') 'Proposal does not name the standalone Guard release.'
    Assert-True ($Workflow -notmatch 'github\.repository') 'Workflow fetches V4 from the current repository.'
    Assert-True ($Workflow -match 'gh release download \$env:V4_RELEASE_TAG --repo von12549/Guard --pattern \$env:V4_ARCHIVE_NAME') 'Workflow does not fetch V4 explicitly from von12549/Guard.'
    $tag = Get-EnvValue $Workflow 'V4_RELEASE_TAG'; $asset = Get-EnvValue $Workflow 'V4_ARCHIVE_NAME'; $digest = Get-EnvValue $Workflow 'V4_ARCHIVE_SHA256'
    Assert-True ($tag -ceq $remote.guardRelease.tag) 'Workflow release tag differs from the live Guard release.'
    $matching = @($releaseAssets | Where-Object { [string]$_.name -ceq $asset })
    Assert-True ($matching.Count -eq 1) "Release asset is missing from the live Guard release: $asset"
    Assert-True ($digest -ceq $Proposal.identity.baseArchiveSha256 -and ([string]$matching[0].digest) -ceq "sha256:$digest") 'Archive digest drift between specimen, proposal and live release.'
    Assert-True ($Workflow.Contains("throw 'V4 release archive hash mismatch.'")) 'Archive hash verification is missing.'
    # Missing bundle: the specimen must refuse an unpublished bundle rather than continue.
    Assert-True ($Workflow.Contains("throw 'The exact IFX bundle has not been published into the trusted base by its separate authorization.'")) 'Missing-bundle refusal is absent.'
    # Source-path fallback: nothing may read product source or bundles from docs/guards/v4.
    $bundleBase = Get-EnvValue $Workflow 'IFX_BUNDLE_BASE_PATH'
    Assert-True (-not ([string]$bundleBase).StartsWith('docs/guards/v4/') -and -not ([string]$Proposal.trustedInputs.futureBundleBasePath).StartsWith('docs/guards/v4/')) 'Bundle path falls back to docs/guards/v4.'
    Assert-True ($Workflow -notmatch 'docs/guards/v4/') 'Workflow references the old IFX product source path.'
    # Premature cleanup: docs/guards/v4 may be absent only after the authorized T8 cleanup, proven by the
    # T8 cleanup receipt binding an existing cleanup commit (V4-TODO-008 T8 amendment of this control).
    if ($CoreSourcePresent) {
        Assert-True (-not [bool]$Proposal.boundary.ifxCoreSourceRemoved -and -not [bool]$Proposal.boundary.cleanupAuthorized) 'Cleanup is premature: docs/guards/v4 must remain until T8 is authorized.'
    } else {
        Assert-True ([bool]$Proposal.boundary.ifxCoreSourceRemoved -and [bool]$Proposal.boundary.cleanupAuthorized -and $null -ne $CleanupReceipt) 'Cleanup is premature: docs/guards/v4 is absent without the authorized T8 cleanup receipt.'
        Assert-True ([string]$CleanupReceipt.planId -ceq '20260928-v4-todo-008-t8-ifx-cleanup' -and [string]$CleanupReceipt.status -ceq 'pass' -and [int]$CleanupReceipt.deleted.trackedFileCount -eq 169) 'Cleanup receipt does not bind the authorized T8 Plan.'
        & git -C $root cat-file -e "$([string]$CleanupReceipt.cleanupCommit)^{commit}" 2>$null
        Assert-True ($LASTEXITCODE -eq 0) 'Cleanup receipt names a missing cleanup commit.'
    }
}

$proposalText = Get-Content -Raw -LiteralPath $paths.proposal
$workflowText = Get-Content -Raw -LiteralPath $paths.workflow
$corePresent = Test-Path -LiteralPath (Full 'docs/guards/v4/plugin.json') -PathType Leaf
$cleanupReceiptPath = Full 'docs/guards/v4-adoption/migration/v4-todo-008-ifx-cleanup-receipt.json'
$cleanupReceipt = if ([IO.File]::Exists($cleanupReceiptPath)) { Get-Content -Raw -LiteralPath $cleanupReceiptPath | ConvertFrom-Json -Depth 100 } else { $null }
Test-Design ($proposalText | ConvertFrom-Json -Depth 100) $workflowText $corePresent $cleanupReceipt

# Executed negative controls: every mutation must be rejected by the same design checks.
function Mutate-Json([scriptblock] $Change) { $p = $proposalText | ConvertFrom-Json -Depth 100; & $Change $p; $p }
$controls = @(
    @{ id = 'wrong-release-repository'; proposal = $null; workflow = $workflowText.Replace('--repo von12549/Guard', '--repo ${{ github.repository }}') },
    @{ id = 'missing-release-asset'; proposal = $null; workflow = $workflowText.Replace('V4_ARCHIVE_NAME: v4-guards-1.1.5.zip', 'V4_ARCHIVE_NAME: v4-guards-1.1.5-missing.zip') },
    @{ id = 'archive-hash-drift'; proposal = $null; workflow = $workflowText.Replace("V4_ARCHIVE_SHA256: $($identity.baseArchiveSha256)", "V4_ARCHIVE_SHA256: $('0' * 64)") },
    @{ id = 'missing-bundle'; proposal = $null; workflow = $workflowText.Replace("throw 'The exact IFX bundle has not been published into the trusted base by its separate authorization.'", "Write-Warning 'bundle missing'") },
    @{ id = 'source-path-fallback'; proposal = $null; workflow = $workflowText.Replace('IFX_BUNDLE_BASE_PATH: docs/guards/v4-adoption/', 'IFX_BUNDLE_BASE_PATH: docs/guards/v4/') },
    @{ id = 'candidate-self-judgment'; proposal = $null; workflow = $workflowText.Replace('"$env:RUNNER_TEMP/ifx-trusted-base/docs/guards/candidates/ifx-rebind-115/Test-IFX115CutoverRollback.ps1"', '"./docs/guards/candidates/ifx-rebind-115/Test-IFX115CutoverRollback.ps1"') },
    @{ id = 'premature-cleanup'; proposal = (Mutate-Json { param($p) $p.boundary.ifxCoreSourceRemoved = $true; $p.boundary.cleanupAuthorized = $true }); workflow = $workflowText; noReceipt = $true }
)
$controlResults = [Collections.Generic.List[object]]::new()
foreach ($control in $controls) {
    Assert-True ($control.workflow -cne $workflowText -or $null -ne $control.proposal) "Negative control did not mutate anything: $($control.id)"
    $candidate = if ($null -ne $control.proposal) { $control.proposal } else { $proposalText | ConvertFrom-Json -Depth 100 }
    $rejected = $false; $message = $null
    $receiptForControl = if ($control.ContainsKey('noReceipt')) { $null } else { $cleanupReceipt }
    try { Test-Design $candidate $control.workflow $corePresent $receiptForControl } catch { $rejected = $true; $message = $_.Exception.Message }
    Assert-True $rejected "Negative control was accepted: $($control.id)"
    $controlResults.Add([ordered]@{ id = $control.id; actual = 'rejected'; message = $message })
}
$proposal = $proposalText | ConvertFrom-Json -Depth 100
foreach ($declaredControl in @($proposal.negativeControls)) { Assert-True ($declaredControl.expected -ceq 'rejected') "Declared control is not a rejection: $($declaredControl.id)" }
Assert-True (Same-UniqueSet @($controls | ForEach-Object { $_.id }) @($proposal.negativeControls | Where-Object { $_.executedBy -ceq 't7-successor-rehearsal' } | ForEach-Object id)) 'Executed controls differ from the proposal declaration.'

$protected = [ordered]@{
    baseInstall = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.5'
    composedInstall = [string]$identity.roots.composedInstall
    acceptedBundle = Full ([string]$identity.roots.bundle)
    cleanTarget = [string]$identity.roots.cleanTarget
    violatingTarget = [string]$identity.roots.violatingTarget
}
$pre = [ordered]@{}; foreach ($name in $protected.Keys) { $pre[$name] = Get-TreeDigest $protected[$name] }
[void][IO.Directory]::CreateDirectory($evidence)
Write-Json (Join-Path $evidence 'pre-inventories.json') ([ordered]@{ formatVersion = 1; roots = $pre })
Write-Json (Join-Path $evidence 'rehearsal.json') ([ordered]@{
    formatVersion = 1; status = 'pass'; entryIdentities = 'pass'; remoteSnapshot = 'pass'
    contextOwnershipRows = @($proposal.contextOwnership).Count; detectorOwnershipRows = @($proposal.detectorOwnership).Count
    states = @($proposal.states | ForEach-Object id); transitions = @($proposal.transitions | ForEach-Object id)
    declaredNegativeControls = @($proposal.negativeControls | ForEach-Object { [ordered]@{ id = $_.id; expected = $_.expected } })
    executedNegativeControls = @($controlResults.ToArray())
    activationBlockers = @($proposal.activationPrerequisites)
})
$post = [ordered]@{}
foreach ($name in $protected.Keys) { $post[$name] = Get-TreeDigest $protected[$name]; Assert-True ($post[$name].sha256 -ceq $pre[$name].sha256) "Protected root mutated: $name" }
Write-Json (Join-Path $evidence 'post-inventories.json') ([ordered]@{ formatVersion = 1; roots = $post })
Write-Json (Join-Path $evidence 'p10-3-successor-decision.json') ([ordered]@{
    formatVersion = 1; status = 'pass'; decision = 'p10-3-successor-design-and-local-rehearsal-accepted'
    planId = '20260928-v4-todo-008-t7-ifx-consumer-rebinding'
    supersedes = [ordered]@{ decision = 'p10-3-design-and-local-rehearsal-accepted'; sha256 = '529e19b567c05619ec054117e2514c579a908a4e614355411fc28b6d52964964'; status = 'historical' }
    identity = $proposal.identity
    remote = [ordered]@{ ifxDevelopmentCommit = $remote.developmentBranch.remoteCommit; rulesetId = $remote.ruleset.id; requiredContextCount = @($remote.ruleset.requiredContexts).Count; guardReleaseTag = $remote.guardRelease.tag; remoteMutationPerformed = $false }
    proof = [ordered]@{ contextOwnershipRows = @($proposal.contextOwnership).Count; detectorOwnershipRows = @($proposal.detectorOwnership).Count; executedNegativeControls = $controlResults.Count; protectedRootsUnchanged = $true }
    activationBlockers = @($proposal.activationPrerequisites)
    boundary = [ordered]@{ p10_3SuccessorDesignComplete = $true; p10GatePassed = $false; workflowInstalled = $false; rulesetChanged = $false; activated = $false; ifxCutover = $false; ifxCoreSourceRemoved = (-not $corePresent); cleanupReceiptSha256 = $(if ($null -ne $cleanupReceipt) { (Get-FileHash -Algorithm SHA256 -LiteralPath $cleanupReceiptPath).Hash.ToLowerInvariant() } else { $null }); v3Retired = $false }
})
Write-Output "T7 P10.3 successor rehearsal PASS: $evidence"
