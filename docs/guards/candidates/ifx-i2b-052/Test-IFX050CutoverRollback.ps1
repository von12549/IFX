# IFX I2-B amendment A3 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A3-10c: P10.3 successor rehearsal for
# V4 Guards 1.1.6 from von12549/Guard + ifx_profile 0.5.2. Successor of candidates/ifx-i2b-051/Test-IFX050CutoverRollback.ps1
# (unchanged). The design, evidence-model and ownership rules stay; A3 adds the closure rule (finding F-C1): every path
# the specimen runs from the trusted base, the staging script and every producer script lie under docs/guards/v4-adoption,
# and no producer names docs/guards/candidates. The aggregate is docs/guards/v4-adoption/ci/Invoke-IFXV4Aggregate.ps1;
# the Aggregate mode below is kept for the lab tree only.
[CmdletBinding()]
param(
    [ValidateSet('Validate','Aggregate')][string] $Mode = 'Validate',
    [string] $RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path,
    [string] $IdentityPath = 'docs/guards/candidates/ifx-i2b-052/a310-identity.json',
    [string] $EvidenceRoot = 'artifacts/guards/p10-ifx-i2b/a3-052/p10-3-successor-052/rehearsal',
    [ValidateSet('success','failure','cancelled','skipped')][string] $ContractResult = 'success',
    [ValidateSet('success','failure','cancelled','skipped')][string] $WindowsResult = 'success'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# The removed IFX product copy, assembled so that this harness never names it literally.
$removedPrefix = 'docs/guards/' + 'v4/'

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

# Entry identities: every A1 record must match the committed identity file.
foreach ($name in @('c6cDecision','windowsFull','c6dDecision','c6eDecision','p10_2Decision','parityAgainst051','hostOutcomesAgainst051','remoteSnapshot')) {
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
$s6 = Get-Content -Raw -LiteralPath (Full $identity.records.c6dDecision.path) | ConvertFrom-Json -Depth 100
$s7 = Get-Content -Raw -LiteralPath (Full $identity.records.c6eDecision.path) | ConvertFrom-Json -Depth 100
$parity044 = Get-Content -Raw -LiteralPath (Full $identity.records.parityAgainst051.path) | ConvertFrom-Json -Depth 100
$hostOutcomes = Get-Content -Raw -LiteralPath (Full $identity.records.hostOutcomesAgainst051.path) | ConvertFrom-Json -Depth 100
$p10 = Get-Content -Raw -LiteralPath (Full $identity.records.p10_2Decision.path) | ConvertFrom-Json -Depth 100
$remote = Get-Content -Raw -LiteralPath (Full $identity.records.remoteSnapshot.path) | ConvertFrom-Json -Depth 100
$required = Get-Content -Raw -LiteralPath $paths.requiredChecks | ConvertFrom-Json -Depth 100
$releaseAssets = @($remote.guardRelease.assets)

Assert-True ($c6c.status -ceq 'pass' -and $c6c.baseVersion -ceq '1.1.6' -and $c6c.candidateVersion -ceq '0.5.2') 'C6c decision identity mismatch.'
Assert-True ($windows.status -ceq 'pass' -and $windows.platform -ceq 'windows' -and $windows.baseVersion -ceq '1.1.6' -and $windows.bundleVersion -ceq '0.5.2') 'Windows-full identity mismatch.'
Assert-True ($s6.status -ceq 'pass' -and $s6.decision -ceq 'c6d-exact-bundle-human-review-accepted' -and $s6.candidateVersion -ceq '0.5.2') 'A3-9 human review is not accepted.'
Assert-True ($s7.status -ceq 'pass' -and $s7.decision -ceq 'a3-10a-composition-accepted' -and $s7.checks.stagedPostPass -and $s7.checks.unstagedPostFailsClosed) 'A3-10a composition is not accepted.'
Assert-True ($p10.status -ceq 'pass' -and $p10.decision -ceq 'p10-2-parity-accepted' -and $p10.gapCount -eq 0) 'P10.2 parity is not zero-gap accepted.'
Assert-True ($parity044.status -ceq 'pass' -and $parity044.p10_2Replay.equalToPredecessor -and @($parity044.independentMatrix.outcomeGaps).Count -eq 0) 'Parity against 0.5.1 did not pass.'
Assert-True ($hostOutcomes.status -ceq 'pass') 'Installed-Host outcomes differ from 0.5.1.'
Assert-True ($remote.status -ceq 'pass' -and $remote.mode -ceq 'github-get-only') 'Remote snapshot is not a passing GET-only capture.'
Assert-True ($remote.ruleset.id -eq 23459908 -and $remote.ruleset.enforcement -ceq 'active' -and $remote.ruleset.strict) 'Live IFX ruleset boundary mismatch.'

function Test-Design($Proposal, [string] $Workflow, [bool] $CoreSourcePresent, $CleanupReceipt) {
    # Accepted P10.3 rules (unchanged semantics).
    $declared = @($required.jobs | Where-Object blocking | ForEach-Object id)
    Assert-True ($Proposal.identity.targetCommit -ceq $c6c.targetCommit -and $windows.sourceCommit -ceq $Proposal.identity.targetCommit -and $s7.targetCommit -ceq $Proposal.identity.targetCommit) 'Target commit is not shared across C6c, S7 and proposal.'
    Assert-True ($s7.composition.packageHash -ceq $Proposal.identity.packageSha256) 'Composed Package identity mismatch.'
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
    Assert-True ($Workflow -match 'pwsh -NoProfile -File "\$env:RUNNER_TEMP/ifx-trusted-base/docs/guards/v4-adoption/ci/Invoke-IFXV4Aggregate\.ps1" -ContractResult') 'Aggregate is not evaluated from the trusted base.'
    Assert-True ($Workflow -match 'git worktree add --detach "\$env:RUNNER_TEMP/ifx-trusted-base" \$env:BASE_SHA') 'Trusted base is not materialized from the PR base commit.'
    # Standalone release source: explicit Guard repository, exact tag, asset and digest.
    Assert-True ($Proposal.trustedInputs.baseReleaseRepository -ceq 'von12549/Guard' -and $Proposal.trustedInputs.baseReleaseTag -ceq 'v4-guards-v1.1.6') 'Proposal does not name the standalone Guard release.'
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
    Assert-True (-not ([string]$bundleBase).StartsWith($removedPrefix, [StringComparison]::OrdinalIgnoreCase) -and -not ([string]$Proposal.trustedInputs.futureBundleBasePath).StartsWith($removedPrefix, [StringComparison]::OrdinalIgnoreCase)) 'Bundle path falls back to docs/guards/v4.'
    Assert-True ($Workflow -notmatch ('(?i)' + [regex]::Escape($removedPrefix))) 'Workflow references the old IFX product source path (any letter case).'
    # 0.5.0-a evidence model: producers run and stage from the trusted base, before Pre and Post, and the evidence
    # (staged locks and the production record) is uploaded even when Post fails.
    $model = $Proposal.evidenceModel
    Assert-True ($model.model -ceq 'staged-by-workflow' -and $model.stagingScriptSource -ceq 'previously-trusted-base' -and [bool]$model.postWithoutStagingFailsClosed) 'Evidence model is not staged-by-workflow from the trusted base.'
    Assert-True ((Get-EnvValue $Workflow 'IFX_EVIDENCE_PRODUCERS') -ceq [string]$model.stagingScript) 'Specimen staging script differs from the proposal.'
    $produce = $Workflow.IndexOf('-File "$env:RUNNER_TEMP/ifx-trusted-base/$env:IFX_EVIDENCE_PRODUCERS" -Phase Produce -TargetRoot $env:GITHUB_WORKSPACE')
    $stage = $Workflow.IndexOf('-File "$env:RUNNER_TEMP/ifx-trusted-base/$env:IFX_EVIDENCE_PRODUCERS" -Phase Stage -TargetRoot $env:GITHUB_WORKSPACE')
    $preRun = $Workflow.IndexOf('stage run --stage pre'); $postRun = $Workflow.IndexOf('stage run --stage post')
    Assert-True ($produce -ge 0 -and $stage -ge 0) 'Producers or staging do not run from the trusted base.'
    Assert-True ($Workflow -match '-Phase Stage -TargetRoot \$env:GITHUB_WORKSPACE -RunRecordPath "\$env:RUNNER_TEMP/v4-ifx-production\.json" -EvidenceRoot \$env:V4_IFX_EVIDENCE') 'Staging does not target the Host EvidenceRoot.'
    Assert-True ($produce -lt $stage -and $stage -lt $preRun -and $preRun -lt $postRun) 'Evidence is not produced and staged before Pre and Post.'
    Assert-True ($Workflow -match '(?ms)if:\s+always\(\)\s*\r?\n\s+with:\s*\r?\n\s+name:\s+v4-ifx-evidence-\$\{\{ github\.sha \}\}\s*\r?\n\s+path:\s*\|\s*\r?\n\s+\$\{\{ runner\.temp \}\}/v4-ifx-evidence\s*\r?\n\s+\$\{\{ runner\.temp \}\}/v4-ifx-production\.json') 'Staged evidence and the production record are not always uploaded.'
    # Ownership after the relocation (A2): no consumed producer runs a V3 gate or reads V3/V3_ifx, so every producer and every
    # context is attested v4-native and the 0.5.0-a re-attestation marker may not return anywhere in the proposal.
    $v3Read = [regex]'(?i)docs[\\/]+guards[\\/]+(V3_ifx|V3)[\\/]'
    foreach ($producer in @($model.producers)) {
        Assert-True (-not [bool]$producer.wrapsV3Gate -and [string]$producer.attestation -ceq 'v4-native-producer') "Producer is not v4-native: $($producer.gate)"
        $script = Full ([string]$producer.script)
        Assert-True ([IO.File]::Exists($script)) "Producer script is missing: $($producer.script)"
        $body = @([IO.File]::ReadAllLines($script) | Where-Object { -not $_.StartsWith('# Relocated from docs/guards/', [StringComparison]::Ordinal) }) -join "`n"
        Assert-True (-not $v3Read.IsMatch($body)) "Producer reads V3 or V3_ifx: $($producer.gate)"
    }
    Assert-True (@($Proposal.contextOwnership | Where-Object { [string]$_.attestation -like '*re-attests*' }).Count -eq 0) 'A context is still declared as re-attesting a V3 producer.'
    Assert-True (@($Proposal.detectorOwnership | Where-Object { [string]$_.status -like '*re-attests*' }).Count -eq 0) 'A detector family is still declared as re-attesting a V3 producer.'
    # Closure (A3, finding F-C1): main admits only docs/guards/v4-adoption, so every trusted-base path of the specimen, the
    # staging script and every producer script lie under it, and no producer names docs/guards/candidates (any case; the
    # provenance header line excepted).
    $adoption = 'docs/guards/v4-adoption/'
    $specimenPaths = @([regex]::Matches($Workflow, '(?i)docs/guards/[A-Za-z0-9_./-]*[A-Za-z0-9_]') | ForEach-Object { $_.Value } | Sort-Object -Unique)
    foreach ($path in $specimenPaths) { Assert-True ($path.StartsWith($adoption, [StringComparison]::Ordinal)) "Specimen names a path outside docs/guards/v4-adoption: $path" }
    Assert-True (([string]$model.stagingScript).StartsWith("${adoption}ci/", [StringComparison]::Ordinal)) 'The staging script is not under docs/guards/v4-adoption/ci.'
    $labRead = [regex]'(?i)docs[\\/]+guards[\\/]+candidates([\\/''"]|$)'
    foreach ($producer in @($model.producers)) {
        Assert-True (([string]$producer.script).StartsWith("${adoption}producers/", [StringComparison]::Ordinal)) "Producer is outside docs/guards/v4-adoption/producers: $($producer.gate)"
        $body = @([IO.File]::ReadAllLines((Full ([string]$producer.script))) | Where-Object { -not $_.StartsWith('# Relocated from docs/guards/', [StringComparison]::Ordinal) }) -join "`n"
        Assert-True (-not $labRead.IsMatch($body)) "Producer names the lab tree: $($producer.gate)"
    }
    Assert-True (([string](Get-EnvValue $Workflow 'IFX_BUNDLE_BASE_PATH')).EndsWith('/0.5.2') -and $Proposal.identity.ifxProfileVersion -ceq '0.5.2') 'Specimen does not bind the 0.5.2 bundle.'
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
$corePresent = Test-Path -LiteralPath (Full ($removedPrefix + 'plugin.json')) -PathType Leaf
$cleanupReceiptPath = Full 'docs/guards/v4-adoption/migration/v4-todo-008-ifx-cleanup-receipt.json'
$cleanupReceipt = if ([IO.File]::Exists($cleanupReceiptPath)) { Get-Content -Raw -LiteralPath $cleanupReceiptPath | ConvertFrom-Json -Depth 100 } else { $null }
Test-Design ($proposalText | ConvertFrom-Json -Depth 100) $workflowText $corePresent $cleanupReceipt

# Executed negative controls: every mutation must be rejected by the same design checks.
function Mutate-Json([scriptblock] $Change) { $p = $proposalText | ConvertFrom-Json -Depth 100; & $Change $p; $p }
$controls = @(
    @{ id = 'wrong-release-repository'; proposal = $null; workflow = $workflowText.Replace('--repo von12549/Guard', '--repo ${{ github.repository }}') },
    @{ id = 'missing-release-asset'; proposal = $null; workflow = $workflowText.Replace('V4_ARCHIVE_NAME: v4-guards-1.1.6.zip', 'V4_ARCHIVE_NAME: v4-guards-1.1.6-missing.zip') },
    @{ id = 'archive-hash-drift'; proposal = $null; workflow = $workflowText.Replace("V4_ARCHIVE_SHA256: $($identity.baseArchiveSha256)", "V4_ARCHIVE_SHA256: $('0' * 64)") },
    @{ id = 'missing-bundle'; proposal = $null; workflow = $workflowText.Replace("throw 'The exact IFX bundle has not been published into the trusted base by its separate authorization.'", "Write-Warning 'bundle missing'") },
    @{ id = 'source-path-fallback'; proposal = $null; workflow = $workflowText.Replace('IFX_BUNDLE_BASE_PATH: docs/guards/v4-adoption/', "IFX_BUNDLE_BASE_PATH: $removedPrefix") },
    @{ id = 'candidate-self-judgment'; proposal = $null; workflow = $workflowText.Replace('"$env:RUNNER_TEMP/ifx-trusted-base/docs/guards/v4-adoption/ci/Invoke-IFXV4Aggregate.ps1"', '"./docs/guards/v4-adoption/ci/Invoke-IFXV4AggregaerRollback.ps1"') },
    @{ id = 'installer-from-target-source'; proposal = $null; workflow = $workflowText.Replace("(Join-Path `$expanded 'package/core/distribution/Install-V4Distribution.ps1')", "(Join-Path `$env:GITHUB_WORKSPACE '" + 'docs/guards/' + "V4/core/distribution/Install-V4Distribution.ps1')") },
    @{ id = 'premature-cleanup'; proposal = (Mutate-Json { param($p) $p.boundary.ifxCoreSourceRemoved = $true; $p.boundary.cleanupAuthorized = $true }); workflow = $workflowText; noReceipt = $true },
    @{ id = 'producer-step-missing'; proposal = $null; workflow = [regex]::Replace($workflowText, '(?ms)      - name: Produce IFX evidence.*?(?=      - name: Stage IFX evidence)', '') },
    @{ id = 'staging-from-candidate'; proposal = $null; workflow = $workflowText.Replace('-File "$env:RUNNER_TEMP/ifx-trusted-base/$env:IFX_EVIDENCE_PRODUCERS" -Phase Stage', '-File "./$env:IFX_EVIDENCE_PRODUCERS" -Phase Stage') },
    @{ id = 'post-before-staging'; proposal = $null; workflow = [regex]::Replace($workflowText, '(?ms)(      - name: Stage IFX evidence into EvidenceRoot.*?)(      - name: Run trusted IFX Pre.*?)(      - uses: actions/upload-artifact@v4\s*\r?\n\s+if: always\(\))', '$2$1$3') },
    @{ id = 'evidence-upload-missing'; proposal = $null; workflow = [regex]::Replace($workflowText, '(?m)^\s+\$\{\{ runner\.temp \}\}/v4-ifx-production\.json\s*\r?\n', '') },
    @{ id = 'producer-reads-v3'; proposal = (Mutate-Json { param($p) @($p.evidenceModel.producers | Where-Object gate -CEQ 'solution')[0].script = 'docs/guards/candidates/ifx-gate-coverage-c5b/Invoke-IFXSolutionEvidenceProducer.ps1' }); workflow = $workflowText },
    @{ id = 'specimen-reads-lab-tree'; proposal = (Mutate-Json { param($p) $p.evidenceModel.stagingScript = 'docs/guards/candidates/ifx-i2b-051/Invoke-IFX050EvidenceProducers.ps1' }); workflow = $workflowText.Replace('IFX_EVIDENCE_PRODUCERS: docs/guards/v4-adoption/ci/Invoke-IFXEvidenceProducers.ps1', 'IFX_EVIDENCE_PRODUCERS: docs/guards/candidates/ifx-i2b-051/Invoke-IFX050EvidenceProducers.ps1') },
    @{ id = 'producer-reads-lab-tree'; proposal = (Mutate-Json { param($p) @($p.evidenceModel.producers | Where-Object gate -CEQ 'graph')[0].script = 'docs/guards/candidates/ifx-gate-coverage-c1r2b/Invoke-IFXEvaluatedGraphProducer.ps1' }); workflow = $workflowText },
    @{ id = 're-attestation-returns'; proposal = (Mutate-Json { param($p) @($p.contextOwnership | Where-Object v3Context -CEQ 'v3-specialized-database')[0].attestation = 're-attests-v3-producer-until-0.5.0-b' }); workflow = $workflowText }
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
Assert-True (Same-UniqueSet @($controls | ForEach-Object { $_.id }) @($proposal.negativeControls | Where-Object { $_.executedBy -cin @('t7-successor-rehearsal','i1-successor-rehearsal','a18-successor-rehearsal','a210-successor-rehearsal','a310-successor-rehearsal') } | ForEach-Object id)) 'Executed controls differ from the proposal declaration.'

$protected = [ordered]@{
    baseInstall = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6'
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
    planId = '20260929-v4-ifx-i2b-ci-evidence-and-bundle'; step = 'A3-10c'
    supersedes = [ordered]@{ decision = 'p10-3-successor-design-and-local-rehearsal-accepted'; sha256 = '893693904ab17371491d1d3eb24267de8bbf7b1ca48c0142d89fc0ba65aa45e2'; tuple = 'V4 Guards 1.1.6 + ifx_profile 0.5.1'; status = 'historical' }
    evidenceModel = [ordered]@{ model = [string]$proposal.evidenceModel.model; stagingScriptSource = [string]$proposal.evidenceModel.stagingScriptSource; reAttestedV3Producers = @($proposal.evidenceModel.producers | Where-Object { [bool]$_.wrapsV3Gate } | ForEach-Object gate); v4NativeProducers = @($proposal.evidenceModel.producers | ForEach-Object gate) }
    identity = $proposal.identity
    remote = [ordered]@{ ifxDevelopmentCommit = $remote.developmentBranch.remoteCommit; rulesetId = $remote.ruleset.id; requiredContextCount = @($remote.ruleset.requiredContexts).Count; guardReleaseTag = $remote.guardRelease.tag; remoteMutationPerformed = $false }
    proof = [ordered]@{ contextOwnershipRows = @($proposal.contextOwnership).Count; detectorOwnershipRows = @($proposal.detectorOwnership).Count; executedNegativeControls = $controlResults.Count; protectedRootsUnchanged = $true }
    activationBlockers = @($proposal.activationPrerequisites)
    boundary = [ordered]@{ p10_3SuccessorDesignComplete = $true; p10GatePassed = $false; workflowInstalled = $false; rulesetChanged = $false; activated = $false; ifxCutover = $false; ifxCoreSourceRemoved = (-not $corePresent); cleanupReceiptSha256 = $(if ($null -ne $cleanupReceipt) { (Get-FileHash -Algorithm SHA256 -LiteralPath $cleanupReceiptPath).Hash.ToLowerInvariant() } else { $null }); v3Retired = $false }
})
Write-Output "A3-10c P10.3 successor rehearsal PASS: $evidence"
