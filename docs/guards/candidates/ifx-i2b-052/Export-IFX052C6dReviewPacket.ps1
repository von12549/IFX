# IFX I2-B amendment A3 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A3-9: the C6d review packet of ifx_profile
# 0.5.2 on V4 Guards 1.1.6. The predecessor is the accepted 0.5.1 packet (A2-9). 0.5.2 changes only the producer identity
# of one lock consumer (ifx-c1-evaluated-reference, finding F-C1, rulings R12-R16) and the Profile lineage. The packet
# requires that nothing else changed against the 0.5.1 bundle, checks every changed field against an exact allow-list,
# binds the closure evidence (A3-1 to A3-7) and the A3-8 C6c, carries the accepted claims forward unchanged and writes
# review.md. Successor of Export-IFX051C6dReviewPacket.ps1 (unchanged). Nothing here is acceptance.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BundleRoot,
    [Parameter(Mandatory)][string]$OutputRoot,
    [Parameter(Mandatory)][string]$ExpectedTargetCommit,
    [Parameter(Mandatory)][string]$ExpectedManifestSha256,
    [string]$C6cDecisionPath = 'artifacts/guards/p10-ifx-i2b/a3-052/c6c-decision.json',
    [string]$C6cSummaryPath = 'artifacts/guards/p10-ifx-i2b/a3-052/c6c-full/summary.json',
    [string]$PredecessorBundleRoot = 'artifacts/guards/p10-ifx-i2b/a2-051/formal-candidate-a/cddff38a8d04481298b7882ab038e322/bundle',
    [string]$PredecessorManifestSha256 = 'b7a6751612f2279809b07988916112b499c52e7b1b36ae175c68924bd979e5e7',
    [string]$PredecessorDecisionPath = 'artifacts/guards/p10-ifx-i2b/a2-051/c6d-review-051/c6d-decision.json',
    [string]$PredecessorPacketPath = 'artifacts/guards/p10-ifx-i2b/a2-051/c6d-review-051/review-packet.json',
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
function Canon($Value) { $Value | ConvertTo-Json -Depth 50 -Compress }
# Every leaf that differs between two JSON values, as JSON Pointer -> (from, to).
function Get-JsonDiff($A, $B, [string]$Pointer = '') {
    if ($A -is [Collections.IDictionary] -and $B -is [Collections.IDictionary]) {
        foreach ($k in @(@($A.Keys) + @($B.Keys) | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive -Unique)) { Get-JsonDiff $A[$k] $B[$k] "$Pointer/$k" }
    } elseif ($A -is [Collections.IList] -and $B -is [Collections.IList] -and $A -isnot [string] -and $A.Count -eq $B.Count) {
        for ($i = 0; $i -lt $A.Count; $i++) { Get-JsonDiff $A[$i] $B[$i] "$Pointer/$i" }
    } elseif ((Canon $A) -cne (Canon $B)) { [ordered]@{ pointer = $Pointer; from = $A; to = $B } }
}
$moduleId = 'ifx-c1-evaluated-reference'
$graphScript = 'docs/guards/v4-adoption/producers/graph/Invoke-IFXEvaluatedGraphProducer.ps1'
$stagingScript = 'docs/guards/v4-adoption/ci/Invoke-IFXEvidenceProducers.ps1'
$output = Full $OutputRoot; if (Test-Path -LiteralPath $output) { Fail "Output already exists: $output" }
$bundle = Full $BundleRoot; $manifestFile = Join-Path $bundle 'bundle-manifest.json'

# 1. Identity of the certified 0.5.2 candidate and of the accepted 0.5.1 predecessor.
if ((Hash $manifestFile) -cne $ExpectedManifestSha256) { Fail 'Bundle manifest differs from the C6c candidate.' }
$manifest = Read-Json $manifestFile; $decision = Read-Json $C6cDecisionPath; $summary = Read-Json $C6cSummaryPath
if ($manifest.version -cne '0.5.2' -or $manifest.baseVersion -cne '1.1.6') { Fail 'Bundle is not 1.1.6 / 0.5.2.' }
if ($decision.status -cne 'pass' -or $decision.decision -cne 'phase-1-complete-stop-for-human-review' -or $decision.targetCommit -cne $ExpectedTargetCommit -or $decision.candidate.manifestSha256 -cne $ExpectedManifestSha256) { Fail 'C6c decision does not bind this passing candidate.' }
if ($summary.status -cne 'pass' -or $summary.productCertification.status -cne 'pass' -or [bool]$summary.portabilityAssessment.blocking -or $summary.portabilityAssessment.status -cne 'pass' -or $summary.sourceCommit -cne $ExpectedTargetCommit) { Fail 'C6c summary is not passing.' }
$predPackage = Join-Path (Full $PredecessorBundleRoot) 'package'
$predManifestFile = Join-Path (Full $PredecessorBundleRoot) 'bundle-manifest.json'
if ((Hash $predManifestFile) -cne $PredecessorManifestSha256) { Fail 'Predecessor 0.5.1 manifest drift.' }
$predDecision = Read-Json $PredecessorDecisionPath
if ($predDecision.decision -cne 'c6d-exact-bundle-human-review-accepted' -or $predDecision.bundle.manifestSha256 -cne $PredecessorManifestSha256 -or $predDecision.acceptedEvidence.reviewPacket.sha256 -cne (Hash $PredecessorPacketPath)) { Fail 'The 0.5.1 predecessor is not the accepted packet.' }
$pred = Read-Json $predManifestFile

# 2. Exact file inventory and module ceilings.
$packageRoot = Join-Path $bundle 'package'
$files = @(foreach ($e in @($manifest.files)) { $p = Join-Path $packageRoot $e.path; if ((Get-IFX050Sha256 $p) -cne $e.sha256 -or (Get-Item -LiteralPath $p).Length -ne [long]$e.size) { Fail "Bundle file drift: $($e.path)" }; [ordered]@{ path = $e.path; size = [long]$e.size; sha256 = $e.sha256 } })
if (@(Get-ChildItem -LiteralPath $packageRoot -File -Recurse -Force).Count -ne $files.Count) { Fail 'Undeclared bundle files.' }
$ceilings = @(foreach ($m in @($manifest.modules)) { [ordered]@{ moduleId = $m.id; version = $m.version; allowedCapabilities = $m.allowedCapabilities } })

# 3. 0.5.1 -> 0.5.2: exactly the graph consumer's three files and the three Profile files.
$old = @{}; foreach ($e in @($pred.files)) { $old[[string]$e.path] = [string]$e.sha256 }
$new = @{}; foreach ($e in $files) { $new[[string]$e.path] = [string]$e.sha256 }
$changed = @($new.Keys | Where-Object { $old.ContainsKey($_) -and $old[$_] -cne $new[$_] } | Sort-Object)
$added = @($new.Keys | Where-Object { -not $old.ContainsKey($_) }); $removed = @($old.Keys | Where-Object { -not $new.ContainsKey($_) })
if ($added.Count -or $removed.Count) { Fail "0.5.2 adds or removes package files: +$($added -join ',') -$($removed -join ',')" }
$expectedChanged = @("modules/$moduleId/adapter.ps1", "modules/$moduleId/module.json", "modules/$moduleId/policy.json", 'profiles/catalog/ifx_profile/authority-map.json', 'profiles/catalog/ifx_profile/evidence-lineage.json', 'profiles/catalog/ifx_profile/profile.json') | Sort-Object
if (($changed -join '|') -cne ($expectedChanged -join '|')) { Fail "Changed files differ from the expected six: $($changed -join ', ')" }
$om = @{}; foreach ($m in @($pred.modules)) { $om[[string]$m.id] = $m }
$versionChanges = @(foreach ($m in @($manifest.modules)) { $o = $om[[string]$m.id]
    if ((Canon $o.allowedCapabilities) -cne (Canon $m.allowedCapabilities)) { Fail "Capability ceiling changed: $($m.id)" }
    if ($o.version -cne $m.version) { if ($m.id -cne $moduleId) { Fail "Unexpected module version change: $($m.id)" }; [ordered]@{ moduleId = $m.id; from = $o.version; to = $m.version } } })
if (@($versionChanges).Count -ne 1 -or $versionChanges[0].from -cne '0.2.0' -or $versionChanges[0].to -cne '0.2.1') { Fail 'Exactly ifx-c1-evaluated-reference must change version, 0.2.0 -> 0.2.1.' }

# 4. Every changed JSON field against its allow-list.
function Assert-Allowed([string]$File, [object[]]$Diffs, [scriptblock]$Allowed) {
    $bad = @($Diffs | Where-Object { -not (& $Allowed $_) })
    if ($bad.Count) { Fail "Unexpected change in ${File}: $(@($bad | ForEach-Object { $_.pointer }) -join ', ')" }
    , @($Diffs | ForEach-Object { [ordered]@{ pointer = $_.pointer; from = $_.from; to = $_.to } })
}
$fieldChanges = [ordered]@{}
$policyDiff = @(Get-JsonDiff (Read-Json (Join-Path $predPackage "modules/$moduleId/policy.json")) (Read-Json (Join-Path $packageRoot "modules/$moduleId/policy.json")))
$fieldChanges['policy.json'] = Assert-Allowed 'policy.json' $policyDiff { param($d) $d.pointer -in @('/producer/id', '/producer/script', '/producer/scriptSha256', '/producer/policySha256') }
$policyNew = Read-Json (Join-Path $packageRoot "modules/$moduleId/policy.json")
if ($policyNew.producer.id -cne 'ifx-v4a-graph-v1' -or $policyNew.producer.script -cne $graphScript -or $policyNew.producer.scriptSha256 -cne (Get-IFX050PinSha256 (Full $graphScript)) -or $policyNew.producer.policySha256 -cne (Hash 'docs/guards/v4-adoption/producers/graph/policy.json')) { Fail 'The pinned producer is not the relocated graph producer in this tree.' }
$moduleDiff = @(Get-JsonDiff (Read-Json (Join-Path $predPackage "modules/$moduleId/module.json")) (Read-Json (Join-Path $packageRoot "modules/$moduleId/module.json")))
$fieldChanges['module.json'] = Assert-Allowed 'module.json' $moduleDiff { param($d) $d.pointer -in @('/version', '/adapter/sha256', '/authorities/0/sha256') }
$profileDiff = @(Get-JsonDiff (Read-Json (Join-Path $predPackage 'profiles/catalog/ifx_profile/profile.json')) (Read-Json (Join-Path $packageRoot 'profiles/catalog/ifx_profile/profile.json')))
$profileNew = Read-Json (Join-Path $packageRoot 'profiles/catalog/ifx_profile/profile.json')
$selectionIndex = [Array]::IndexOf(@($profileNew.moduleSelections | ForEach-Object { [string]$_.id }), $moduleId)
$fieldChanges['profile.json'] = Assert-Allowed 'profile.json' $profileDiff { param($d) $d.pointer -in @('/version', "/moduleSelections/$selectionIndex/config/policySha256") }
$lineageDiff = @(Get-JsonDiff (Read-Json (Join-Path $predPackage 'profiles/catalog/ifx_profile/evidence-lineage.json')) (Read-Json (Join-Path $packageRoot 'profiles/catalog/ifx_profile/evidence-lineage.json')))
$lineageNew = Read-Json (Join-Path $packageRoot 'profiles/catalog/ifx_profile/evidence-lineage.json')
$graphIndex = [Array]::IndexOf(@($lineageNew.producers | ForEach-Object { [string]$_.gate }), 'graph')
$fieldChanges['evidence-lineage.json'] = Assert-Allowed 'evidence-lineage.json' $lineageDiff { param($d) $d.pointer -in @('/sourceCommit', '/ordinalInventorySha256', '/changeSpecSha256', '/stagingScript', "/producers/$graphIndex/producerId", "/producers/$graphIndex/script", "/producers/$graphIndex/scriptSha256") }
if ($lineageNew.stagingScript -cne $stagingScript -or @($lineageNew.producers | Where-Object { -not ([string]$_.script).StartsWith('docs/guards/v4-adoption/producers/', [StringComparison]::Ordinal) }).Count) { Fail 'The lineage names a producer or staging script outside docs/guards/v4-adoption.' }
$mapOld = Read-Json (Join-Path $predPackage 'profiles/catalog/ifx_profile/authority-map.json'); $mapNew = Read-Json (Join-Path $packageRoot 'profiles/catalog/ifx_profile/authority-map.json')
$mapDiff = @(Get-JsonDiff $mapOld $mapNew)
$mapIndex = [Array]::IndexOf(@($mapNew.modules | ForEach-Object { [string]$_.id }), $moduleId)
$fieldChanges['authority-map.json'] = Assert-Allowed 'authority-map.json' $mapDiff { param($d)
    ($d.pointer -in @('/sourceCommit', '/changeSpecSha256', "/modules/$mapIndex/version", "/modules/$mapIndex/adapterSha256", "/modules/$mapIndex/manifestSha256", "/modules/$mapIndex/authorities/0/sha256")) -or
    ($d.pointer -match '^/modules/\d+/sourcePath$' -and ([string]$d.from).Replace('candidates/ifx-i2b-051/', 'candidates/ifx-i2b-052/') -ceq [string]$d.to) }
$sourcePathOnly = @($fieldChanges['authority-map.json'] | Where-Object { $_.pointer -match '/sourcePath$' }).Count
$adapterOld = [IO.File]::ReadAllLines((Join-Path $predPackage "modules/$moduleId/adapter.ps1")); $adapterNew = [IO.File]::ReadAllLines((Join-Path $packageRoot "modules/$moduleId/adapter.ps1"))
if ($adapterOld.Count -ne $adapterNew.Count) { Fail 'The adapter gained or lost lines.' }
$adapterLines = @(for ($i = 0; $i -lt $adapterNew.Count; $i++) { if ($adapterOld[$i] -cne $adapterNew[$i]) { [ordered]@{ line = $i + 1; from = $adapterOld[$i]; to = $adapterNew[$i] } } })
if (@($adapterLines | Where-Object { $_.line -notin 3, 4, 92, 95 }).Count -or $adapterLines.Count -ne 4) { Fail "Unexpected adapter lines changed: $(@($adapterLines | ForEach-Object line) -join ',')" }

# 5. Evidence of the relocation, bound by hash.
$evidence = [ordered]@{
    closureSpec = Bound 'docs/guards/candidates/ifx-i2b-052/closure-spec.json'; closureInventory = Bound 'docs/guards/candidates/ifx-i2b-052/closure-inventory.json'
    origins = Bound 'docs/guards/v4-adoption/producers/origins.json'; closureControls = Bound 'artifacts/guards/p10-ifx-i2b/a3-closure/a3-3-controls.json'
    parity = Bound 'artifacts/guards/p10-ifx-i2b/a3-closure/a3-4-parity.json'; suiteOutcomes = Bound 'artifacts/guards/p10-ifx-i2b/a3-closure/a3-5-suites/index.json'
    suiteIndex = Bound 'artifacts/guards/p10-ifx-i2b/a3-closure/suite-index-052.json'; trial = Bound 'artifacts/guards/p10-ifx-i2b/a3-closure/a3-6-trial/index.json'
    readiness = Bound 'artifacts/guards/p10-ifx-i2b/a3-closure/a3-7-readiness/index.json'; changeSpec = Bound 'docs/guards/candidates/ifx-i2b-052/change-spec.json' }
$closure = Read-Json $evidence.closureInventory.path; $controls = Read-Json $evidence.closureControls.path; $parity = Read-Json $evidence.parity.path; $suites = Read-Json $evidence.suiteOutcomes.path
if ($closure.status -cne 'pass' -or $controls.status -cne 'pass' -or $parity.status -cne 'pass' -or $parity.semanticDifferenceCount -ne 0 -or $parity.negativeMismatchCount -ne 0 -or $parity.aggregateDifferenceCount -ne 0 -or $suites.status -cne 'pass') { Fail 'Relocation evidence is not passing.' }

$limits = @(
    'The lab originals of the relocated graph producer, its policy, the two source policies and the staging script stay in docs/guards/candidates on the development branch; Copy-IFX052Closure.ps1 -Check reports any later change to them as drift for review; it does not sync.'
    'The two source policies under producers/graph/policies are byte copies kept as hashed data: their provenance fields still name V3 paths, which the producer never reads (A3-3 control).'
    'The specimen and proposal still bind 0.5.1 and the lab-tree staging and aggregate paths; A3-10 rebinds them to 0.5.2 and adds the closure rule with its negative controls.'
    'The hosted runner''s prerequisites for the producers (for example the pinned .NET SDK 10.0.303 of the graph producer and SQL Server for the database matrix) are proved only when the specimen is installed and negative-tested (I2-E).'
    'Linux remains a non-blocking portability assessment; the synthetic review fixture is a test input, not acceptance.'
    'Publishing to main (I2-D), the ruleset, P10.GATE and V3 retirement remain separate decisions.')

[void][IO.Directory]::CreateDirectory($output)
$inventoryOut = Join-Path $output 'file-inventory.json'; $ceilingsOut = Join-Path $output 'module-ceilings.json'; $comparisonOut = Join-Path $output 'predecessor-comparison.json'
Write-IFX050Json $inventoryOut ([ordered]@{ formatVersion = 1; bundleManifestSha256 = $ExpectedManifestSha256; fileCount = $files.Count; files = $files })
Write-IFX050Json $ceilingsOut ([ordered]@{ formatVersion = 1; bundleManifestSha256 = $ExpectedManifestSha256; moduleCount = $ceilings.Count; moduleCeilings = $ceilings })
Write-IFX050Json $comparisonOut ([ordered]@{ formatVersion = 1; predecessorVersion = '0.5.1'; predecessorManifestSha256 = $PredecessorManifestSha256; bundleManifestSha256 = $ExpectedManifestSha256
    rule = 'only ifx-c1-evaluated-reference (adapter, module.json, policy) and the three IFX Profile files change; no file added or removed; ceilings identical; every changed JSON field is on its allow-list; four adapter lines change'
    changedPackageFiles = @($changed | ForEach-Object { [ordered]@{ path = $_; old = $old[$_]; new = $new[$_] } }); moduleVersionChanges = @($versionChanges)
    fieldChanges = $fieldChanges; adapterLines = @($adapterLines) })

$nl = "`n"; $md = [Text.StringBuilder]::new(); function L([string]$Line = '') { [void]$md.Append($Line + $nl) }
$p = $fieldChanges['policy.json']; function Value($List, [string]$Pointer, [string]$Side) { [string](@($List | Where-Object { $_.pointer -ceq $Pointer })[0].$Side) }
L '# C6d review packet: ifx_profile 0.5.2 on V4 Guards 1.1.6'; L
L 'Status: `ready-for-designated-human-review` - review decision pending (A3-9).'; L
L "- Target commit ``$ExpectedTargetCommit``; bundle manifest ``$ExpectedManifestSha256``; base archive ``$ExpectedBaseArchiveSha256``."
L "- C6c decision ``$(Hash $C6cDecisionPath)``: Windows product certification pass (independent matrix $($summary.windows.provenCoreCases)/191, controls $($summary.controls.capabilityVariantCount) capability + $($summary.controls.lockControlCount) staged-evidence); Linux portability pass ($($summary.portabilityAssessment.provenCoreCases)/191, semantic projection $($summary.portabilityAssessment.semanticProjection), non-blocking)."
L "- Predecessor: the accepted 0.5.1 packet (``$($predDecision.acceptedEvidence.reviewPacket.sha256.Substring(0,8))…``, bundle ``$($PredecessorManifestSha256.Substring(0,8))…``)."
L; L '## What to decide'; L
L 'Accept or reject this exact packet. 0.5.2 changes one thing (finding F-C1 of I2-C): the graph lock consumer pins the graph producer relocated to `docs/guards/v4-adoption/producers/graph/`, and the Profile lineage names the staging script under `docs/guards/v4-adoption/ci/`, so no producer or staging path of the bundle lies under `docs/guards/candidates`. What every module claims ("pass means") is the accepted 0.5.1 text, unchanged. Acceptance permits writing the production review record and continuing with A3-10 locally; it does not authorize a push, a workflow, a ruleset or publishing.'
L; L '## What changed against 0.5.1'; L
L "- $($changed.Count) package files changed, none added or removed; module ceilings identical; one version change: ``$moduleId`` $($versionChanges[0].from) -> $($versionChanges[0].to)."
L "- Producer: ``$(Value $p '/producer/id' 'from')`` -> ``$(Value $p '/producer/id' 'to')``; script ``$(Value $p '/producer/script' 'from')`` -> ``$(Value $p '/producer/script' 'to')``; script and policy hashes accordingly."
L "- Adapter: four lines (the header comment naming the staging script, the lock path prefix ``p10-ifx-c1-r2b/evaluation-runs`` -> ``v4a-producers/graph-runs``, the producer id in the lock check). No check or claim changes."
L "- Profile: the version and the module's ``policySha256``. Lineage: ``stagingScript`` -> ``$stagingScript``, the graph producer entry, and the source commit, inventory and change-spec hashes."
L "- Authority map: the module's version and hashes, the source commit and change-spec hash, and $sourcePathOnly provenance ``sourcePath`` values of the lab tree (``ifx-i2b-051`` -> ``ifx-i2b-052``)."
L; L '## Evidence that the relocated closure behaves like the lab one'; L
L "- **Closure inventory (A3-1).** $($closure.counts.references) references over $($closure.counts.roots) roots; nothing unlisted; every path outside ``v4-adoption`` is a listed relocate origin and maps under ``v4-adoption`` after relocation."
L '- **Byte-identical copy, then a separate adaptation (A3-2, A3-3).** The copy commit''s Git blobs equal the origins; the adaptation is reviewable line by line. Closure controls pass with nine negative mutations (lab and V3 paths in any case, a staging script naming a missing or lab producer, a policy source back in the lab or with a drifted hash, an escape from the package, a parsed source policy, a parse error).'
L "- **Parity (A3-4).** On one clean clone the lab and relocated graph producers give semantically equal locks ($($parity.graph.positive.identity.edges) edges, $($parity.graph.positive.identity.projects) projects; $($parity.semanticDifferenceCount) differences). Negative parity $(@($parity.graph.negative.Values | Where-Object { $_.sameFailure }).Count)/$(@($parity.graph.negative.Values).Count). The extracted aggregate equals the lab branch for $(@($parity.aggregate | Where-Object { $_.equal }).Count)/16 input combinations."
L "- **Consumer suite (A3-5).** $($suites.caseTotal) catalog cases pass on evidence from the relocated staging script and producers; the cases shared with the accepted A1-3 record agree in kind, expectation, outcome, findings and message."
L '- **Trial, readiness (A3-6, A3-7) and C6c (A3-8).** All pass; see the bound records.'
L; L '## Open limits'; L
foreach ($l in $limits) { L "- $l" }
L; L '## Files'; L
L '`review-packet.json` binds this file, `predecessor-comparison.json` (every changed file, field and adapter line), `file-inventory.json`, `module-ceilings.json` and the closure evidence by SHA-256.'
$reviewOut = Join-Path $output 'review.md'; [IO.File]::WriteAllText($reviewOut, $md.ToString(), [Text.UTF8Encoding]::new($false))

$packet = [ordered]@{
    formatVersion = 1; status = 'ready-for-designated-human-review'; scope = 'c6d-exact-bundle-review'; step = 'A3-9'; planId = '20260929-v4-ifx-i2b-ci-evidence-and-bundle'
    reviewDecision = 'pending'; acceptedBy = $null; targetCommit = $ExpectedTargetCommit; baseVersion = '1.1.6'; candidateVersion = '0.5.2'
    bundle = [ordered]@{ id = [string]$manifest.id; manifestPath = Rel $manifestFile; manifestSha256 = $ExpectedManifestSha256; baseArchiveSha256 = $ExpectedBaseArchiveSha256; profileCount = 1; moduleCount = $ceilings.Count; fileCount = $files.Count }
    predecessor = [ordered]@{ version = '0.5.1'; manifestSha256 = $PredecessorManifestSha256; decision = Bound $PredecessorDecisionPath; packet = Bound $PredecessorPacketPath; claimsCarriedForward = $true }
    outputs = [ordered]@{ review = Bound $reviewOut; predecessorComparison = Bound $comparisonOut; fileInventory = Bound $inventoryOut; moduleCeilings = Bound $ceilingsOut }
    closureEvidence = $evidence
    certification = [ordered]@{ decision = Bound $C6cDecisionPath; summary = Bound $C6cSummaryPath; windowsCoreCases = [int]$summary.windows.provenCoreCases
        controls = [ordered]@{ capability = [int]$summary.controls.capabilityVariantCount; stagedEvidence = [int]$summary.controls.lockControlCount }
        linuxPortability = [ordered]@{ blocking = $false; status = [string]$summary.portabilityAssessment.status; semanticProjection = [string]$summary.portabilityAssessment.semanticProjection; coreCases = [int]$summary.portabilityAssessment.provenCoreCases } }
    openLimits = $limits
    requiredAuthority = [ordered]@{ authorityType = 'human-review'; authorityId = 'xiaolong-feng'; candidateHostVerdictAllowed = $false }
    decisionBoundary = [ordered]@{ startAuthorizationIsAcceptance = $false; syntheticReviewIsAcceptance = $false; c6eAuthorized = $false; instruction = 'Review the exact packet and explicitly accept or reject it. Do not compose (A3-10) before acceptance.' }
}
$packetOut = Join-Path $output 'review-packet.json'; Write-IFX050Json $packetOut $packet
Write-IFX050Json (Join-Path $output 'summary.json') ([ordered]@{ formatVersion = 1; status = 'pass'; result = 'ready-for-designated-human-review'; reviewPacketPath = Rel $packetOut; reviewPacketSha256 = Hash $packetOut; reviewSha256 = Hash $reviewOut; productionReviewRecordCreated = $false; c6eAuthorized = $false })
Write-Output "C6d review packet (0.5.2) ready; human decision pending: $packetOut"
