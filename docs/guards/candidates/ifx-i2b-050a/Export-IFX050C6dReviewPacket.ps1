# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-7: the C6d review packet of
# ifx_profile 0.5.0 on V4 Guards 1.1.6; successor of candidates/ifx-rebind-116/Export-IFX116C6dReviewPacket.ps1
# (unchanged). Besides the exact bundle inventory and ceilings it states, per module, what "pass" means in 0.5.0-a
# (change spec, check changes, lock bindings, suite evidence), the 0.4.4 -> 0.5.0 comparison and the open limits.
# It writes review.md for the human reader; the packet JSON binds every input by hash. Nothing here is acceptance.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BundleRoot,
    [Parameter(Mandatory)][string]$C6cDecisionPath,
    [Parameter(Mandatory)][string]$C6cSummaryPath,
    [Parameter(Mandatory)][string]$WindowsCaseManifestPath,
    [Parameter(Mandatory)][string]$OrdinalInventoryPath,
    [Parameter(Mandatory)][string]$OutputRoot,
    [Parameter(Mandatory)][string]$ExpectedTargetCommit,
    [Parameter(Mandatory)][string]$ExpectedManifestSha256,
    [Parameter(Mandatory)][string]$PredecessorBundleRoot,
    [string]$PredecessorManifestSha256 = 'f71b47543252104370330d4c2ca68cc059a8d1279a7bb1f662361ab6584a64b7',
    [string]$ExpectedBaseArchiveSha256 = '92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8',
    [string]$ChangeSpecPath = (Join-Path $PSScriptRoot 'change-spec.json'),
    [string]$CheckChangesPath = (Join-Path $PSScriptRoot 'check-changes.json')
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'IFX050.Tooling.psm1') -Force
function Fail([string]$Message) { throw $Message }
function Hash([string]$Path) { Get-IFX050Sha256 $Path }
function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -Depth 100 }
function Full-File([string]$Path, [string]$Label) { $f = [IO.Path]::GetFullPath($Path); if (-not [IO.File]::Exists($f)) { Fail "$Label is missing: $f" }; $f }
function Full-Directory([string]$Path, [string]$Label) { $f = [IO.Path]::GetFullPath($Path); if (-not [IO.Directory]::Exists($f)) { Fail "$Label is missing: $f" }; $f }
function Is-Under([string]$Path, [string]$Root) { $r = [IO.Path]::GetRelativePath($Root, $Path); -not [IO.Path]::IsPathRooted($r) -and $r -ne '..' -and -not $r.StartsWith("..$([IO.Path]::DirectorySeparatorChar)") }
function Bound([string]$Path) { [ordered]@{ path = $Path; sha256 = (Hash $Path) } }

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
function Rel([string]$Path) { [IO.Path]::GetRelativePath($repo, $Path).Replace('\', '/') }
$bundle = Full-Directory $BundleRoot 'Bundle root'
$decisionFile = Full-File $C6cDecisionPath 'C6c decision'; $summaryFile = Full-File $C6cSummaryPath 'C6c summary'
$caseFile = Full-File $WindowsCaseManifestPath 'Windows case manifest'; $inventoryFile = Full-File $OrdinalInventoryPath 'Ordinal inventory'
$specFile = Full-File $ChangeSpecPath 'Change spec'; $checkFile = Full-File $CheckChangesPath 'Check changes'
$manifestFile = Full-File (Join-Path $bundle 'bundle-manifest.json') 'Bundle manifest'
$output = [IO.Path]::GetFullPath($OutputRoot)
if ([IO.Directory]::Exists($output) -or [IO.File]::Exists($output)) { Fail "Output already exists: $output" }
foreach ($input in @($bundle, $decisionFile, $summaryFile, $caseFile, $inventoryFile)) { if ((Is-Under $output $input) -or (Is-Under $input $output)) { Fail 'Output must be disjoint from every review input.' } }

# 1. Identity of the certified candidate.
$manifestHash = Hash $manifestFile
if ($manifestHash -cne $ExpectedManifestSha256) { Fail 'Bundle manifest identity differs from the C6c candidate.' }
$manifest = Read-Json $manifestFile; $decision = Read-Json $decisionFile; $summary = Read-Json $summaryFile; $cases = Read-Json $caseFile
if ([string]$manifest.baseVersion -cne '1.1.6' -or [string]$manifest.version -cne '0.5.0') { Fail 'Bundle version tuple is not 1.1.6 / 0.5.0.' }
if ([string]$decision.status -cne 'pass' -or [string]$decision.decision -cne 'phase-1-complete-stop-for-human-review') { Fail 'C6c decision is not a passing human-review handoff.' }
if ([string]$decision.targetCommit -cne $ExpectedTargetCommit -or [string]$summary.sourceCommit -cne $ExpectedTargetCommit -or [string]$cases.sourceCommit -cne $ExpectedTargetCommit) { Fail 'C6c target commit mismatch.' }
if ([string]$decision.candidate.manifestSha256 -cne $manifestHash -or [string]$cases.bundleManifestSha256 -cne $manifestHash) { Fail 'C6c records do not bind this candidate.' }
if ([string]$summary.status -cne 'pass' -or [string]$summary.productCertification.status -cne 'pass') { Fail 'C6c product certification is not passing.' }
if ([bool]$summary.portabilityAssessment.blocking -or [string]$summary.portabilityAssessment.status -cne 'pass') { Fail 'The Linux portability assessment did not pass.' }
if ([string]$decision.inventory.sha256 -cne (Hash $inventoryFile)) { Fail 'Ordinal inventory identity mismatch.' }
$coreCases = @($cases.cases); if ($coreCases.Count -ne 191 -or @($coreCases | Where-Object { $_.status -cne 'pass' }).Count -ne 0) { Fail 'Windows case manifest is not 191 passing core cases.' }

# 2. Exact file inventory and module ceilings (as in 0.4.4).
$packageRoot = Join-Path $bundle 'package'
$declared = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase); $files = [Collections.Generic.List[object]]::new()
foreach ($entry in @($manifest.files)) {
    $relative = [string]$entry.path; if (-not $declared.Add($relative)) { Fail "Duplicate or case-colliding manifest path: $relative" }
    $candidate = [IO.Path]::GetFullPath((Join-Path $packageRoot $relative))
    if (-not (Is-Under $candidate $packageRoot) -or -not [IO.File]::Exists($candidate)) { Fail "Manifest file is missing or escapes the package: $relative" }
    $item = Get-Item -LiteralPath $candidate -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) { Fail "Bundle link is not reviewable: $relative" }
    $actual = Hash $candidate; if ($actual -cne [string]$entry.sha256 -or $item.Length -ne [long]$entry.size) { Fail "Bundle file drift: $relative" }
    $files.Add([ordered]@{ path = $relative; size = [long]$item.Length; sha256 = $actual })
}
$actualFiles = @(Get-ChildItem -LiteralPath $packageRoot -File -Recurse -Force | ForEach-Object { [IO.Path]::GetRelativePath($packageRoot, $_.FullName).Replace('\', '/') })
if ($actualFiles.Count -ne $files.Count) { Fail 'Actual bundle file count differs from the manifest.' }
foreach ($relative in $actualFiles) { if (-not $declared.Contains($relative)) { Fail "Undeclared bundle file: $relative" } }
$ceilings = @(foreach ($module in @($manifest.modules)) { $c = $module.allowedCapabilities
    [ordered]@{ moduleId = [string]$module.id; version = [string]$module.version; allowedCapabilities = [ordered]@{ readRoots = @($c.readRoots); writeRoots = @($c.writeRoots); processes = @($c.processes); network = [bool]$c.network; maxTimeoutSeconds = [int]$c.maxTimeoutSeconds } } })
if ($files.Count -ne 262 -or $ceilings.Count -ne 36 -or @($manifest.profiles).Count -ne 1) { Fail "Bundle cardinality differs from the reviewed candidate: files=$($files.Count) modules=$($ceilings.Count)" }

# 3. 0.4.4 -> 0.5.0: only module versions, EvidenceRoot reads for four consumers, and package files may change.
$predecessor = Full-Directory $PredecessorBundleRoot 'Predecessor bundle root'
$predecessorManifestFile = Full-File (Join-Path $predecessor 'bundle-manifest.json') 'Predecessor manifest'
if ((Hash $predecessorManifestFile) -cne $PredecessorManifestSha256) { Fail 'Predecessor 0.4.4 manifest identity drift.' }
$old = Read-Json $predecessorManifestFile
$oldFiles = @{}; foreach ($e in @($old.files)) { $oldFiles[[string]$e.path] = [string]$e.sha256 }
$newFiles = @{}; foreach ($e in $files) { $newFiles[[string]$e.path] = [string]$e.sha256 }
$changedFiles = @($newFiles.Keys | Where-Object { $oldFiles.ContainsKey($_) -and $oldFiles[$_] -cne $newFiles[$_] } | Sort-Object)
$addedFiles = @($newFiles.Keys | Where-Object { -not $oldFiles.ContainsKey($_) } | Sort-Object)
$removedFiles = @($oldFiles.Keys | Where-Object { -not $newFiles.ContainsKey($_) } | Sort-Object)
if ($removedFiles.Count -ne 0) { Fail "0.5.0 removes package files: $($removedFiles -join ', ')" }
$oldModules = @{}; foreach ($m in @($old.modules)) { $oldModules[[string]$m.id] = $m }
$versionChanges = [Collections.Generic.List[object]]::new(); $ceilingChanges = [Collections.Generic.List[object]]::new()
foreach ($m in @($manifest.modules)) {
    $id = [string]$m.id; if (-not $oldModules.ContainsKey($id)) { Fail "Module added in 0.5.0: $id" }
    $o = $oldModules[$id]
    if ([string]$o.version -cne [string]$m.version) { $versionChanges.Add([ordered]@{ moduleId = $id; from = [string]$o.version; to = [string]$m.version }) }
    $oc = $o.allowedCapabilities; $nc = $m.allowedCapabilities
    $same = (@($oc.writeRoots) -join '|') -ceq (@($nc.writeRoots) -join '|') -and (@($oc.processes) -join '|') -ceq (@($nc.processes) -join '|') -and [bool]$oc.network -eq [bool]$nc.network -and [int]$oc.maxTimeoutSeconds -eq [int]$nc.maxTimeoutSeconds
    if (-not $same) { Fail "Module $id changes writes, processes, network or timeout." }
    $addedReads = @(@($nc.readRoots) | Where-Object { @($oc.readRoots) -notcontains $_ }); $removedReads = @(@($oc.readRoots) | Where-Object { @($nc.readRoots) -notcontains $_ })
    if ($removedReads.Count -ne 0 -or @($addedReads | Where-Object { $_ -cne 'EvidenceRoot' }).Count -ne 0) { Fail "Module $id changes read roots beyond adding EvidenceRoot." }
    if ($addedReads.Count -ne 0) { $ceilingChanges.Add([ordered]@{ moduleId = $id; addedReadRoots = $addedReads }) }
}
if (@($old.modules).Count -ne @($manifest.modules).Count) { Fail 'Module count differs from 0.4.4.' }

# 4. What "pass" means per module: change spec, check changes, lock policy and suite evidence.
$spec = Read-Json $specFile; $checks = Read-Json $checkFile
if ([string]$spec.target.profileVersion -cne '0.5.0') { Fail 'Change spec is not for 0.5.0.' }
$suiteById = @{}
$windowsSummary = Read-Json (Full-File (Join-Path ([IO.Path]::GetDirectoryName($caseFile)) 'summary.json') 'Windows matrix summary')
foreach ($s in @($windowsSummary.suites)) { $suiteById[[string]$s.moduleId] = $s }
$claims = [Collections.Generic.List[object]]::new()
foreach ($m in @($spec.modules)) {
    $id = [string]$m.id; $disposition = @($m.disposition)
    $bindings = @($m.bindings)
    # Every binding that is not kept is dropped: live sources, reconciled registries (R1), the regenerated G03
    # projection (R2) and lab policies embedded in the module.
    $dropped = @($bindings | Where-Object { $_.action -cne 'keep-pin' } | ForEach-Object { [ordered]@{ field = $_.field; path = $_.path; class = $_.class; action = $_.action } })
    $kept = @($bindings | Where-Object { $_.action -ceq 'keep-pin' } | ForEach-Object { [ordered]@{ field = $_.field; path = $_.path; class = $_.class; action = $_.action } })
    $moduleCases = @($coreCases | Where-Object { $_.moduleId -ceq $id })
    $lock = $null
    if ($m.lockBinding) {
        $policyFile = Join-Path $packageRoot "modules/$id/policy.json"; $policy = if ([IO.File]::Exists($policyFile)) { Read-Json $policyFile } else { $null }
        $lock = [ordered]@{ gate = $m.lockBinding.gate; producerId = $m.lockBinding.producerId; producerScript = $m.lockBinding.script; freshness = $m.lockBinding.freshness
            producerScriptSha256 = $(if ($policy -and $policy.Contains('producer')) { $policy.producer.scriptSha256 } else { $null })
            checkIds = $(if ($policy -and $policy.Contains('checkIds')) { @($policy.checkIds) } else { @() }) }
    }
    $means = switch -Regex ($disposition -join ',') {
        '^unchanged$' { 'Unchanged from the accepted 0.4.4 module: the same check over the current Target.' }
        default {
            $parts = [Collections.Generic.List[string]]::new()
            if ($lock) { $parts.Add("Reads the staged '$($lock.gate)' evidence lock. Pass requires a lock produced by $($lock.producerId) (script hash pinned in the module policy) for the Target HEAD commit, within $($lock.freshness), with a matching source-tree fingerprint and matching evidence file hashes, and passing verdicts inside that evidence. A missing lock is prerequisite-missing; an inconsistent one is integrity-failure.") }
            if ($lock) { $parts.Add("The Profile lock fields ($(@($m.profileConfig.remove | Where-Object { $_ -like 'evidenceLock*' }) -join ', ')) are removed.") }
            if ($dropped.Count) {
                $byClass = ($dropped | Group-Object { $_.class } | Sort-Object Name | ForEach-Object { "$($_.Count) $($_.Name)" }) -join ', '
                $parts.Add("$($dropped.Count) formerly pinned input(s) are no longer Profile-pinned ($byClass)" + $(if ($lock) { '; see the check basis for what they are compared with.' } else { ': the checks evaluate their current content, so ordinary edits pass and rule-breaking edits still block.' }))
            }
            if ($kept.Count) { $parts.Add("$($kept.Count) governance input(s) stay pinned (LF-normalized SHA-256 for text, ruling R5); any edit is integrity-failure until the bundle is re-reviewed.") }
            if ($m.checkBasis) { $parts.Add("Check basis: $($m.checkBasis)") }
            $parts -join ' '
        }
    }
    $suite = $suiteById[$id]
    $claims.Add([ordered]@{
        moduleId = $id; stage = $m.stage; version = [ordered]@{ from = $m.version; to = $m.newVersion }; disposition = $disposition; passMeans = $means
        droppedPins = $dropped; keptPins = $kept; lockBinding = $lock; couplings = @($m.couplings)
        checkChanges = @(@($checks.changes) | Where-Object { $_.module -ceq $id })
        c6cEvidence = [ordered]@{ suiteMode = $(if ($suite) { $suite.mode } else { $null }); suiteStatus = $(if ($suite) { $suite.status } else { $null }); coreCases = $moduleCases.Count
            caseKinds = @($moduleCases | Group-Object { $_.kind } | Sort-Object Name | ForEach-Object { [ordered]@{ kind = $_.Name; count = $_.Count } }) }
    })
}
if ($claims.Count -ne 37 -or @($claims | Where-Object { $_.disposition -notcontains 'unchanged' }).Count -ne 25) { Fail 'Change spec does not describe 37 modules with 25 changed.' }
$droppedTotal = ($claims | ForEach-Object { @($_.droppedPins).Count } | Measure-Object -Sum).Sum; $keptTotal = ($claims | ForEach-Object { @($_.keptPins).Count } | Measure-Object -Sum).Sum
if ($droppedTotal -ne [int]$spec.summary.bindingsDropped -or $keptTotal -ne [int]$spec.summary.bindingsKept) { Fail "Pin totals $droppedTotal/$keptTotal differ from the change spec summary." }
$specVersions = @{}; foreach ($c in $claims) { $specVersions[$c.moduleId] = $c.version.to }
foreach ($m in @($manifest.modules)) { if ($specVersions[[string]$m.id] -cne [string]$m.version) { Fail "Bundle version of $($m.id) differs from the change spec." } }

$limits = @(
    'Evidence model staged-by-workflow: Post no longer builds or tests; six lock consumers pass only when the workflow ran the pinned producers at the same commit. The CI workflow with producer, staging and upload steps is not installed yet (A1-8 rehearsal, then I2-C/D).',
    'Four of the six producers still wrap V3 gates (Invoke-IFXGuardrails -Mode Quality/Specialized); the Profile keeps the V3_ifx specialized root as workspace evidence for the database producer. Both move in 0.5.0-b.',
    'The generated producer pins and reads docs/guards/V3/.../SourceFiles.cs for lineage, and the frontend producer sets a fixed Windows PATH; both are replaced in 0.5.0-b.',
    'Type and graph locks are fresh for one hour; CI must produce them right before Post.',
    'Governance pins (104 kept) make any edit of those documents integrity-failure until a new bundle is reviewed; 126 live pins were dropped.',
    'Linux is a non-blocking portability assessment; product certification is Windows (windows-full and certification-controls).',
    'The candidate''s synthetic review fixture is a test input, not acceptance; the production review record is written only after this human review.',
    'IFX-V4-005 is fixed in the product; its new load test does not force the race (a deterministic test would need an injected TimeProvider).',
    'Harness limit: the zero-source catalog cases delete ignored build outputs in the matrix Target clone; the lock consumers run first.'
)

[void][IO.Directory]::CreateDirectory($output)
$inventoryOut = Join-Path $output 'file-inventory.json'; $ceilingsOut = Join-Path $output 'module-ceilings.json'
$comparisonOut = Join-Path $output 'predecessor-comparison.json'; $claimsOut = Join-Path $output 'claim-changes.json'
Write-IFX050Json $inventoryOut ([ordered]@{ formatVersion = 1; bundleManifestSha256 = $manifestHash; fileCount = $files.Count; files = @($files) })
Write-IFX050Json $ceilingsOut ([ordered]@{ formatVersion = 1; bundleManifestSha256 = $manifestHash; moduleCount = $ceilings.Count; moduleCeilings = $ceilings })
Write-IFX050Json $comparisonOut ([ordered]@{ formatVersion = 1; predecessorVersion = '0.4.4'; predecessorManifestSha256 = $PredecessorManifestSha256; bundleManifestSha256 = $manifestHash
    moduleVersionChanges = @($versionChanges); ceilingChanges = @($ceilingChanges); ceilingRule = 'only EvidenceRoot read access added; writes, processes, network and timeouts identical'
    changedPackageFiles = @($changedFiles | ForEach-Object { [ordered]@{ path = $_; old = $oldFiles[$_]; new = $newFiles[$_] } }); addedPackageFiles = @($addedFiles | ForEach-Object { [ordered]@{ path = $_; sha256 = $newFiles[$_] } }); removedPackageFiles = @() })
Write-IFX050Json $claimsOut ([ordered]@{ formatVersion = 1; bundleManifestSha256 = $manifestHash; changeSpecSha256 = (Hash $specFile); checkChangesSha256 = (Hash $checkFile); summary = $spec.summary; lockLayout = $spec.lockLayout; rulings = $spec.rulings; modules = @($claims) })

# 5. Human-readable review document.
$nl = "`n"; $md = [Text.StringBuilder]::new()
function L([string]$Line = '') { [void]$md.Append($Line + $nl) }
L '# C6d review packet: ifx_profile 0.5.0 on V4 Guards 1.1.6'; L
L 'Status: `ready-for-designated-human-review` - review decision pending (A1-7).'; L
L "- Target commit: ``$ExpectedTargetCommit``; bundle manifest ``$manifestHash``; base archive ``$ExpectedBaseArchiveSha256``."
L "- C6c decision ``$(Hash $decisionFile)``: Windows product certification pass (independent matrix $($summary.windows.provenCoreCases)/191, controls $($summary.controls.capabilityVariantCount) capability + $($summary.controls.lockControlCount) staged-evidence); Linux portability pass ($($summary.portabilityAssessment.provenCoreCases)/191, semantic projection $($summary.portabilityAssessment.semanticProjection), non-blocking)."
L "- Against 0.4.4 (``$($PredecessorManifestSha256.Substring(0,8))…``): $($versionChanges.Count) module versions changed, $($changedFiles.Count) package files changed, $($addedFiles.Count) added, none removed. Four lock consumers gain EvidenceRoot read access; no module gains writes, processes, network or time."
L; L '## What to decide'; L
L 'Accept or reject this exact packet. Acceptance means: for each changed module, the "pass means" statement below is the claim IFX relies on from now on. It permits writing the production review record and continuing with A1-8 (C6e composition, P10.2 parity, P10.3 rehearsal). It does not authorize a push, a workflow, a ruleset or publishing.'
L; L '## Model change'; L
L '- **Lock binding (6 modules).** Post reads evidence staged by workflow producers under `EvidenceRoot/locks/<gate>/` instead of a lock pinned in the Profile. The lock must name the Target HEAD commit, the producer script hash must match the module policy, and every evidence file hash must match.'
$droppedByClass = (@($claims | ForEach-Object { @($_.droppedPins) }) | Group-Object { $_.class } | Sort-Object Count -Descending | ForEach-Object { "$($_.Count) $($_.Name)" }) -join ', '
L "- **Pin split (20 modules).** $droppedTotal pins are dropped ($droppedByClass): live sources and registries are checked by content against the current files (R1), the G03 projection is regenerated in the G03 core module (R2), and lab policies are embedded in the module. $keptTotal governance pins are kept and compared with an LF-normalized SHA-256 (R5)."
L '- **Couplings (6 modules).** V3 and lab inputs are embedded in the module package or recomputed in the module (R2).'
L; L '## Per module'; L
L '| Module | Version | Disposition | Pins dropped / kept | Lock | Core cases |'; L '| --- | --- | --- | --- | --- | --- |'
foreach ($c in $claims) { L "| ``$($c.moduleId)`` | $($c.version.from) -> $($c.version.to) | $($c.disposition -join ', ') | $(@($c.droppedPins).Count) / $(@($c.keptPins).Count) | $(if ($c.lockBinding) { $c.lockBinding.gate } else { '-' }) | $($c.c6cEvidence.coreCases) |" }
L; L '### Pass means (changed modules)'; L
foreach ($c in @($claims | Where-Object { $_.disposition -notcontains 'unchanged' })) {
    L "- **``$($c.moduleId)``** ($($c.disposition -join ', ')). $($c.passMeans)"
    if ($c.lockBinding -and @($c.lockBinding.checkIds).Count) { L "  - Checks: $(@($c.lockBinding.checkIds) -join ', ')." }
    foreach ($k in @($c.couplings)) { L "  - Coupling ($($k.kind)): $($k.detail) -> $($k.action)." }
    foreach ($k in @($c.checkChanges)) { L "  - **Check change** ``$($k.check)`` ($($k.change)): $($k.reason)" }
}
L; L '## Open limits'; L
foreach ($l in $limits) { L "- $l" }
L; L '## Files'; L
L '`review-packet.json` binds every file below by SHA-256: `claim-changes.json` (per-module detail, dropped and kept pin paths), `predecessor-comparison.json`, `file-inventory.json`, `module-ceilings.json`.'
$reviewOut = Join-Path $output 'review.md'; [IO.File]::WriteAllText($reviewOut, $md.ToString(), [Text.UTF8Encoding]::new($false))

$packet = [ordered]@{
    formatVersion = 1; status = 'ready-for-designated-human-review'; scope = 'c6d-exact-bundle-review'; step = 'A1-7'; planId = '20260929-v4-ifx-i2b-ci-evidence-and-bundle'
    reviewDecision = 'pending'; acceptedBy = $null; targetCommit = $ExpectedTargetCommit; baseVersion = '1.1.6'; candidateVersion = '0.5.0'
    bundle = [ordered]@{ id = [string]$manifest.id; manifestPath = Rel $manifestFile; manifestSha256 = $manifestHash; baseArchiveSha256 = $ExpectedBaseArchiveSha256; profileCount = 1; moduleCount = $ceilings.Count; fileCount = $files.Count }
    inputs = [ordered]@{ ordinalInventory = Bound $inventoryFile; changeSpec = Bound $specFile; checkChanges = Bound $checkFile; windowsCaseManifest = Bound $caseFile }
    outputs = [ordered]@{ review = Bound $reviewOut; claimChanges = Bound $claimsOut; predecessorComparison = Bound $comparisonOut; fileInventory = Bound $inventoryOut; moduleCeilings = Bound $ceilingsOut }
    certification = [ordered]@{ decision = Bound $decisionFile; summary = Bound $summaryFile; windowsProductCertification = 'pass'; windowsCoreCases = [int]$summary.windows.provenCoreCases
        controls = [ordered]@{ capability = [int]$summary.controls.capabilityVariantCount; stagedEvidence = [int]$summary.controls.lockControlCount }
        linuxPortability = [ordered]@{ blocking = $false; status = [string]$summary.portabilityAssessment.status; semanticProjection = [string]$summary.portabilityAssessment.semanticProjection; coreCases = [int]$summary.portabilityAssessment.provenCoreCases } }
    openLimits = $limits
    requiredAuthority = [ordered]@{ authorityType = 'human-review'; authorityId = 'xiaolong-feng'; candidateHostVerdictAllowed = $false }
    decisionBoundary = [ordered]@{ startAuthorizationIsAcceptance = $false; syntheticReviewIsAcceptance = $false; c6eAuthorized = $false
        instruction = 'Review the exact packet and explicitly accept or reject it. Do not compose (A1-8) before acceptance.' }
}
foreach ($k in @($packet.inputs.Keys)) { $packet.inputs[$k].path = Rel $packet.inputs[$k].path }
foreach ($k in @($packet.outputs.Keys)) { $packet.outputs[$k].path = Rel $packet.outputs[$k].path }
foreach ($k in @('decision', 'summary')) { $packet.certification[$k].path = Rel $packet.certification[$k].path }
$packetOut = Join-Path $output 'review-packet.json'; Write-IFX050Json $packetOut $packet
Write-IFX050Json (Join-Path $output 'summary.json') ([ordered]@{ formatVersion = 1; status = 'pass'; result = 'ready-for-designated-human-review'; reviewPacketPath = Rel $packetOut; reviewPacketSha256 = (Hash $packetOut)
    reviewSha256 = (Hash $reviewOut); productionReviewRecordCreated = $false; c6eAuthorized = $false })
Write-Output "C6d review packet ready; human decision pending: $packetOut"
