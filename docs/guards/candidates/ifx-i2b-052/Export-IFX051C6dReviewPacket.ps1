# IFX I2-B amendment A2 step A2-9: the C6d review packet of ifx_profile 0.5.1 on V4 Guards 1.1.6. The predecessor is the
# accepted 0.5.0 packet (A1-7). 0.5.1 changes only the producer identity of five lock consumers (ruling R6-R11): the packet
# requires that nothing else changed against the 0.5.0 bundle, lists each producer change, binds the relocation evidence
# (A2-1 to A2-7) and the A2-8 C6c, carries the accepted 0.5.0 claims forward unchanged, and writes review.md.
# Nothing here is acceptance.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BundleRoot,
    [Parameter(Mandatory)][string]$OutputRoot,
    [Parameter(Mandatory)][string]$ExpectedTargetCommit,
    [Parameter(Mandatory)][string]$ExpectedManifestSha256,
    [string]$C6cDecisionPath = 'artifacts/guards/p10-ifx-i2b/a3-052/c6c-decision.json',
    [string]$C6cSummaryPath = 'artifacts/guards/p10-ifx-i2b/a3-052/c6c-full/summary.json',
    [string]$PredecessorBundleRoot = 'artifacts/guards/p10-ifx-i2b/formal-candidate-a/40bd4b845f2c4dec81efbb36481810cc/bundle',
    [string]$PredecessorManifestSha256 = '086a3911a2cb8f5cef0caf7621cecaf49dcc9bf08e30acd8a376748b9e38a284',
    [string]$PredecessorDecisionPath = 'artifacts/guards/p10-ifx-i2b/c6d-review-050/c6d-decision.json',
    [string]$PredecessorPacketPath = 'artifacts/guards/p10-ifx-i2b/c6d-review-050/review-packet.json',
    [string]$ExpectedBaseArchiveSha256 = '92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'IFX050.Tooling.psm1') -Force
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }
function Rel([string]$Path) { [IO.Path]::GetRelativePath($repo, (Full $Path)).Replace('\', '/') }
function Hash([string]$Path) { Get-IFX050Sha256 (Full $Path) }
function Bound([string]$Path) { if (-not [IO.File]::Exists((Full $Path))) { throw "Bound file is missing: $Path" }; [ordered]@{ path = Rel $Path; sha256 = Hash $Path } }
function Read-Json([string]$Path) { Get-Content -LiteralPath (Full $Path) -Raw | ConvertFrom-Json -AsHashtable -Depth 100 }
function Fail([string]$Message) { throw $Message }
$output = Full $OutputRoot; if (Test-Path -LiteralPath $output) { Fail "Output already exists: $output" }
$bundle = Full $BundleRoot; $manifestFile = Join-Path $bundle 'bundle-manifest.json'

# 1. Identity of the certified 0.5.1 candidate and of the accepted 0.5.0 predecessor.
if ((Hash $manifestFile) -cne $ExpectedManifestSha256) { Fail 'Bundle manifest differs from the C6c candidate.' }
$manifest = Read-Json $manifestFile; $decision = Read-Json $C6cDecisionPath; $summary = Read-Json $C6cSummaryPath
if ($manifest.version -cne '0.5.1' -or $manifest.baseVersion -cne '1.1.6') { Fail 'Bundle is not 1.1.6 / 0.5.1.' }
if ($decision.status -cne 'pass' -or $decision.decision -cne 'phase-1-complete-stop-for-human-review' -or $decision.targetCommit -cne $ExpectedTargetCommit -or $decision.candidate.manifestSha256 -cne $ExpectedManifestSha256) { Fail 'C6c decision does not bind this passing candidate.' }
if ($summary.status -cne 'pass' -or $summary.productCertification.status -cne 'pass' -or [bool]$summary.portabilityAssessment.blocking -or $summary.portabilityAssessment.status -cne 'pass' -or $summary.sourceCommit -cne $ExpectedTargetCommit) { Fail 'C6c summary is not passing.' }
$predManifestFile = Join-Path (Full $PredecessorBundleRoot) 'bundle-manifest.json'
if ((Hash $predManifestFile) -cne $PredecessorManifestSha256) { Fail 'Predecessor 0.5.0 manifest drift.' }
$predDecision = Read-Json $PredecessorDecisionPath
if ($predDecision.decision -cne 'c6d-exact-bundle-human-review-accepted' -or $predDecision.bundle.manifestSha256 -cne $PredecessorManifestSha256 -or $predDecision.acceptedEvidence.reviewPacket.sha256 -cne (Hash $PredecessorPacketPath)) { Fail 'The 0.5.0 predecessor is not the accepted packet.' }
$pred = Read-Json $predManifestFile

# 2. Exact file inventory and module ceilings.
$packageRoot = Join-Path $bundle 'package'
$files = @(foreach ($e in @($manifest.files)) { $p = Join-Path $packageRoot $e.path; if ((Get-IFX050Sha256 $p) -cne $e.sha256 -or (Get-Item -LiteralPath $p).Length -ne [long]$e.size) { Fail "Bundle file drift: $($e.path)" }; [ordered]@{ path = $e.path; size = [long]$e.size; sha256 = $e.sha256 } })
if (@(Get-ChildItem -LiteralPath $packageRoot -File -Recurse -Force).Count -ne $files.Count) { Fail 'Undeclared bundle files.' }
$ceilings = @(foreach ($m in @($manifest.modules)) { [ordered]@{ moduleId = $m.id; version = $m.version; allowedCapabilities = $m.allowedCapabilities } })

# 3. 0.5.0 -> 0.5.1: only the five moved lock consumers and the IFX Profile files may change.
$moved = @('ifx-solution-evidence', 'ifx-assembly-evidence', 'ifx-frontend-evidence', 'ifx-database-evidence', 'ifx-c1-type-provenance')
$old = @{}; foreach ($e in @($pred.files)) { $old[[string]$e.path] = [string]$e.sha256 }
$new = @{}; foreach ($e in $files) { $new[[string]$e.path] = [string]$e.sha256 }
$changed = @($new.Keys | Where-Object { $old.ContainsKey($_) -and $old[$_] -cne $new[$_] } | Sort-Object)
$added = @($new.Keys | Where-Object { -not $old.ContainsKey($_) }); $removed = @($old.Keys | Where-Object { -not $new.ContainsKey($_) })
if ($added.Count -or $removed.Count) { Fail "0.5.1 adds or removes package files: +$($added -join ',') -$($removed -join ',')" }
$allowedChange = { param($p) ($p -like 'profiles/catalog/ifx_profile/*') -or @($moved | Where-Object { $p.StartsWith("modules/$_/", [StringComparison]::Ordinal) }).Count -eq 1 }
$unexpected = @($changed | Where-Object { -not (& $allowedChange $_) }); if ($unexpected.Count) { Fail "Unexpected 0.5.0 -> 0.5.1 file change: $($unexpected -join ', ')" }
$om = @{}; foreach ($m in @($pred.modules)) { $om[[string]$m.id] = $m }
$versionChanges = @(foreach ($m in @($manifest.modules)) { $o = $om[[string]$m.id]
    if ((($o.allowedCapabilities | ConvertTo-Json -Depth 5 -Compress)) -cne (($m.allowedCapabilities | ConvertTo-Json -Depth 5 -Compress))) { Fail "Capability ceiling changed: $($m.id)" }
    if ($o.version -cne $m.version) { if ($moved -notcontains $m.id) { Fail "Unexpected module version change: $($m.id)" }; [ordered]@{ moduleId = $m.id; from = $o.version; to = $m.version } } })
if (@($versionChanges).Count -ne 5) { Fail 'Exactly the five moved consumers must change version.' }
$profileOld = Read-Json (Join-Path (Full $PredecessorBundleRoot) 'package/profiles/catalog/ifx_profile/profile.json'); $profileNew = Read-Json (Join-Path $packageRoot 'profiles/catalog/ifx_profile/profile.json')
$selOld = @{}; foreach ($s in @($profileOld.moduleSelections)) { $selOld[[string]$s.id] = $s }
$selectionChanges = @(foreach ($s in @($profileNew.moduleSelections)) { $o = $selOld[[string]$s.id]
    $a = $o | ConvertTo-Json -Depth 30 -Compress; $b = $s | ConvertTo-Json -Depth 30 -Compress
    if ($a -cne $b) {
        $keys = @(@($s.config.Keys) + @($o.config.Keys) | Sort-Object -Unique | Where-Object { ($o.config[$_] | ConvertTo-Json -Compress -Depth 20) -cne ($s.config[$_] | ConvertTo-Json -Compress -Depth 20) })
        if ($moved -notcontains $s.id -or ($keys -join ',') -cne 'policySha256' -or $o.versionRange -cne $s.versionRange) { Fail "Unexpected Profile selection change: $($s.id) ($($keys -join ','))" }
        [ordered]@{ moduleId = $s.id; field = 'config.policySha256'; from = $o.config.policySha256; to = $s.config.policySha256 } } })
$otherProfileKeys = @(@($profileNew.Keys) | Where-Object { $_ -notin @('version', 'moduleSelections', 'workspaceEvidence') -and (($profileOld[$_] | ConvertTo-Json -Depth 30 -Compress) -cne ($profileNew[$_] | ConvertTo-Json -Depth 30 -Compress)) })
if ($otherProfileKeys.Count) { Fail "Unexpected Profile change: $($otherProfileKeys -join ', ')" }
$woOld = @($profileOld.workspaceEvidence.relativeRoots); $woNew = @($profileNew.workspaceEvidence.relativeRoots)
$weOther = @($profileNew.workspaceEvidence.Keys | Where-Object { $_ -cne 'relativeRoots' -and (($profileOld.workspaceEvidence[$_] | ConvertTo-Json -Compress) -cne ($profileNew.workspaceEvidence[$_] | ConvertTo-Json -Compress)) })
if ($weOther.Count -or (($woOld | Where-Object { $_ -notlike 'docs/guards/V3_ifx/*' }) -join '|') -cne (($woNew | Where-Object { $_ -notlike 'docs/guards/v4-adoption/producers/*' }) -join '|')) { Fail 'workspaceEvidence changed beyond the relocated root.' }

# 4. The producer identity change per module, from the 0.5.0 and 0.5.1 policies.
$producerChanges = @(foreach ($id in $moved) {
    $po = Read-Json (Join-Path (Full $PredecessorBundleRoot) "package/modules/$id/policy.json"); $pn = Read-Json (Join-Path $packageRoot "modules/$id/policy.json")
    $pa = $po.Clone(); $pb = $pn.Clone(); foreach ($k in @('producer', 'authorityHashes')) { [void]$pa.Remove($k); [void]$pb.Remove($k) }
    if (($pa | ConvertTo-Json -Depth 30 -Compress) -cne ($pb | ConvertTo-Json -Depth 30 -Compress)) { Fail "Policy of $id changed beyond producer and authority hashes." }
    [ordered]@{ moduleId = $id; producer = [ordered]@{ from = $po.producer; to = $pn.producer }
        authorityHashes = $(if ($pn.Contains('authorityHashes')) { [ordered]@{ from = $po.authorityHashes; to = $pn.authorityHashes } } else { $null }) } })

# 5. Evidence of the relocation, bound by hash.
$evidence = [ordered]@{
    relocationSpec = Bound 'docs/guards/candidates/ifx-i2b-052/relocation-spec.json'; relocationInventory = Bound 'docs/guards/candidates/ifx-i2b-052/relocation-inventory.json'
    origins = Bound 'docs/guards/v4-adoption/producers/origins.json'; producerControls = Bound 'artifacts/guards/p10-ifx-i2b/a2-relocation/a2-3-controls.json'
    producerParity = Bound 'artifacts/guards/p10-ifx-i2b/a2-relocation/a2-4-parity.json'; suiteOutcomes = Bound 'artifacts/guards/p10-ifx-i2b/a2-relocation/a2-5-suites/index.json'
    suiteIndex = Bound 'artifacts/guards/p10-ifx-i2b/a2-relocation/suite-index-051.json'; trial = Bound 'artifacts/guards/p10-ifx-i2b/a2-relocation/a2-6-trial/index.json'
    readiness = Bound 'artifacts/guards/p10-ifx-i2b/a2-relocation/a2-7-readiness/index.json'; changeSpec = Bound 'docs/guards/candidates/ifx-i2b-052/change-spec.json' }
$parity = Read-Json $evidence.producerParity.path; $suites = Read-Json $evidence.suiteOutcomes.path; $controls = Read-Json $evidence.producerControls.path
if ($parity.status -cne 'pass' -or $parity.semanticDifferenceCount -ne 0 -or $parity.negativeMismatchCount -ne 0 -or $suites.status -cne 'pass' -or $controls.status -cne 'pass') { Fail 'Relocation evidence is not passing.' }

$limits = @(
    'The V3 originals of the relocated gate logic stay in docs/guards/V3_ifx and keep running in V3 CI during coexistence. Copy-IFX051Producers.ps1 -Check reports any later change to them as drift for review; it does not sync.'
    'The CI workflow with producer, staging and upload steps is still not installed; the hosted runner''s prerequisites for the producers (for example SQL Server for the database matrix) are proved only when the specimen is installed and negative-tested.'
    'Five G03 module policies still name V3_ifx specialized scripts as provenance metadata (sourceScripts); their adapters never read them. Outside A2.'
    'The graph producer stays in the lab tree (candidates/ifx-gate-coverage-c1r2b); it reads nothing under V3.'
    'Linux remains a non-blocking portability assessment; the synthetic review fixture is a test input, not acceptance.'
    'V3 retirement, the ruleset, publishing and P10.GATE remain separate decisions.')

[void][IO.Directory]::CreateDirectory($output)
$inventoryOut = Join-Path $output 'file-inventory.json'; $ceilingsOut = Join-Path $output 'module-ceilings.json'; $comparisonOut = Join-Path $output 'predecessor-comparison.json'
Write-IFX050Json $inventoryOut ([ordered]@{ formatVersion = 1; bundleManifestSha256 = $ExpectedManifestSha256; fileCount = $files.Count; files = $files })
Write-IFX050Json $ceilingsOut ([ordered]@{ formatVersion = 1; bundleManifestSha256 = $ExpectedManifestSha256; moduleCount = $ceilings.Count; moduleCeilings = $ceilings })
Write-IFX050Json $comparisonOut ([ordered]@{ formatVersion = 1; predecessorVersion = '0.5.0'; predecessorManifestSha256 = $PredecessorManifestSha256; bundleManifestSha256 = $ExpectedManifestSha256
    rule = 'only the five moved lock consumers and the IFX Profile files change; no file added or removed; ceilings identical; Profile changes are the version, the five policySha256 values and the relocated workspaceEvidence root'
    changedPackageFiles = @($changed | ForEach-Object { [ordered]@{ path = $_; old = $old[$_]; new = $new[$_] } }); moduleVersionChanges = @($versionChanges)
    profileSelectionChanges = @($selectionChanges); workspaceEvidenceRoots = [ordered]@{ from = $woOld; to = $woNew }; producerChanges = @($producerChanges) })

$nl = "`n"; $md = [Text.StringBuilder]::new(); function L([string]$Line = '') { [void]$md.Append($Line + $nl) }
L '# C6d review packet: ifx_profile 0.5.1 on V4 Guards 1.1.6'; L
L 'Status: `ready-for-designated-human-review` - review decision pending (A2-9).'; L
L "- Target commit ``$ExpectedTargetCommit``; bundle manifest ``$ExpectedManifestSha256``; base archive ``$ExpectedBaseArchiveSha256``."
L "- C6c decision ``$(Hash $C6cDecisionPath)``: Windows product certification pass (independent matrix $($summary.windows.provenCoreCases)/191, controls $($summary.controls.capabilityVariantCount) capability + $($summary.controls.lockControlCount) staged-evidence); Linux portability pass ($($summary.portabilityAssessment.provenCoreCases)/191, semantic projection $($summary.portabilityAssessment.semanticProjection), non-blocking)."
L "- Predecessor: the accepted 0.5.0 packet (``$($predDecision.acceptedEvidence.reviewPacket.sha256.Substring(0,8))…``, bundle ``$($PredecessorManifestSha256.Substring(0,8))…``)."
L; L '## What to decide'; L
L 'Accept or reject this exact packet. 0.5.1 changes one thing: the four V3-wrapping producers (solution, assembly, frontend, database) and the type producer now run from `docs/guards/v4-adoption/producers/`, and no consumed producer reads anything under `docs/guards/V3` or `V3_ifx`. What every module claims ("pass means") is the accepted 0.5.0 text, unchanged. Acceptance permits writing the production review record and continuing with A2-10 locally; it does not authorize a push, a workflow, a ruleset or publishing.'
L; L '## What changed against 0.5.0'; L
L "- $($changed.Count) package files changed, none added or removed; module ceilings identical."
L '- Profile: the version, the `policySha256` of the five moved consumers, and one `workspaceEvidence` root:'
L "  ``$(($woOld | Where-Object { $_ -like 'docs/guards/V3_ifx/*' }) -join ', ')`` -> ``$(($woNew | Where-Object { $_ -like 'docs/guards/v4-adoption/*' }) -join ', ')``."
L; L '| Module | Version | Producer (0.5.0 -> 0.5.1) | Script |'; L '| --- | --- | --- | --- |'
foreach ($p in $producerChanges) { $v = @($versionChanges | Where-Object { $_.moduleId -ceq $p.moduleId })[0]; L "| ``$($p.moduleId)`` | $($v.from) -> $($v.to) | ``$($p.producer.from.id)`` -> ``$($p.producer.to.id)`` | ``$($p.producer.to.script)`` |" }
L; L 'Authority hashes that change are those of the relocated gate scripts (the V3 quality, package-audit and assembly-guard scripts, now adapted copies); the Domain policy and the type rule copies are byte-identical, so their pins are unchanged.'
L; L '## Evidence that the relocated producers behave like the V3 gates'; L
L "- **Inventory (A2-1).** $(( Read-Json $evidence.relocationInventory.path).fileCount) files relocated; every file reference of every origin is classified; no unlisted read into ``docs/guards``."
L '- **Byte-identical copy, then a separate adaptation (A2-2, A2-3).** The copy commit''s Git blobs equal the origins; the adaptation commit is reviewable line by line. Static controls pass with five negative mutations (no V3/V3_ifx/lab path in any case, no escape from the package, refusal without an explicit Target root).'
L "- **V3/V4 parity (A2-4).** On one clean clone the lab producers (V3 gates) and the relocated producers produce semantically identical evidence for all five gates: $($parity.semanticDifferenceCount) differences. Negative parity $(@($parity.negative.Values | Where-Object { $_.sameFailure }).Count)/$(@($parity.negative.Values).Count): a lint error, an unsafe migration policy and a failing test fail both sides at the same check with the same message."
L "- **Consumer suites (A2-5).** $($suites.caseTotal) catalog cases on relocated-producer evidence all pass; the cases shared with the accepted A1-3 records agree in kind, expectation, outcome, findings and message."
L '- **Trial and readiness (A2-6, A2-7), C6c (A2-8).** All pass; see the bound records.'
L; L '## Open limits'; L
foreach ($l in $limits) { L "- $l" }
L; L '## Files'; L
L '`review-packet.json` binds this file, `predecessor-comparison.json` (every changed file, producer and Profile change), `file-inventory.json`, `module-ceilings.json` and the relocation evidence by SHA-256.'
$reviewOut = Join-Path $output 'review.md'; [IO.File]::WriteAllText($reviewOut, $md.ToString(), [Text.UTF8Encoding]::new($false))

$packet = [ordered]@{
    formatVersion = 1; status = 'ready-for-designated-human-review'; scope = 'c6d-exact-bundle-review'; step = 'A2-9'; planId = '20260929-v4-ifx-i2b-ci-evidence-and-bundle'
    reviewDecision = 'pending'; acceptedBy = $null; targetCommit = $ExpectedTargetCommit; baseVersion = '1.1.6'; candidateVersion = '0.5.1'
    bundle = [ordered]@{ id = [string]$manifest.id; manifestPath = Rel $manifestFile; manifestSha256 = $ExpectedManifestSha256; baseArchiveSha256 = $ExpectedBaseArchiveSha256; profileCount = 1; moduleCount = $ceilings.Count; fileCount = $files.Count }
    predecessor = [ordered]@{ version = '0.5.0'; manifestSha256 = $PredecessorManifestSha256; decision = Bound $PredecessorDecisionPath; packet = Bound $PredecessorPacketPath; claimsCarriedForward = $true }
    outputs = [ordered]@{ review = Bound $reviewOut; predecessorComparison = Bound $comparisonOut; fileInventory = Bound $inventoryOut; moduleCeilings = Bound $ceilingsOut }
    relocationEvidence = $evidence
    certification = [ordered]@{ decision = Bound $C6cDecisionPath; summary = Bound $C6cSummaryPath; windowsCoreCases = [int]$summary.windows.provenCoreCases
        controls = [ordered]@{ capability = [int]$summary.controls.capabilityVariantCount; stagedEvidence = [int]$summary.controls.lockControlCount }
        linuxPortability = [ordered]@{ blocking = $false; status = [string]$summary.portabilityAssessment.status; semanticProjection = [string]$summary.portabilityAssessment.semanticProjection; coreCases = [int]$summary.portabilityAssessment.provenCoreCases } }
    openLimits = $limits
    requiredAuthority = [ordered]@{ authorityType = 'human-review'; authorityId = 'xiaolong-feng'; candidateHostVerdictAllowed = $false }
    decisionBoundary = [ordered]@{ startAuthorizationIsAcceptance = $false; syntheticReviewIsAcceptance = $false; c6eAuthorized = $false; instruction = 'Review the exact packet and explicitly accept or reject it. Do not compose (A2-10) before acceptance.' }
}
$packetOut = Join-Path $output 'review-packet.json'; Write-IFX050Json $packetOut $packet
Write-IFX050Json (Join-Path $output 'summary.json') ([ordered]@{ formatVersion = 1; status = 'pass'; result = 'ready-for-designated-human-review'; reviewPacketPath = Rel $packetOut; reviewPacketSha256 = Hash $packetOut; reviewSha256 = Hash $reviewOut; productionReviewRecordCreated = $false; c6eAuthorized = $false })
Write-Output "C6d review packet (0.5.1) ready; human decision pending: $packetOut"
