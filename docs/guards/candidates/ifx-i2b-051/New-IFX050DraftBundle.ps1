# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-4: build and test the ifx_profile
# 0.5.0 candidate bundle; successor of docs/guards/candidates/ifx-gate-coverage-c6b1/Test-IFXC6DraftBundle.ps1 (which
# stays unchanged as historical authority).
# - Module selections come from the composed 0.4.4 Profile. Each module changed by the A1-2 specification gets its
#   0.5.0-a config (New-IFX050ModuleConfig: no lock path or hash, no live pin, governance pins by the R5 hash
#   computed from the Target); the 12 unchanged modules keep their 0.4.4 config.
# - The Profile pins no evidence lock. evidence-lineage.json records the staged-evidence model and the pinned
#   producers instead.
# - workspaceEvidence keeps docs/guards/V3_ifx/stages/post/gates/specialized while the database producer is the V3
#   gate (its source inventory hashes those scripts); the root goes with the producer relocation in 0.5.0-b.
# - The installed Host runs Pre, Post and Post with dependencies on the Target with evidence staged from
#   -ProductionRecord (Invoke-IFX050EvidenceProducers.ps1), and three negative variants.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InventoryPath,
    [Parameter(Mandatory)][string]$ProductionRecord,
    [string]$TargetRoot,
    [string]$BaseInstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6',
    [string]$BaseReceiptPath = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.6.install.json',
    [string]$BaseArchivePath = 'D:/IFX-Root/IFX/artifacts/guards/p10-ifx-116/base-archive/v4-guards-1.1.6.zip',
    [string]$EvidenceRoot = 'artifacts/guards/p10-ifx-i2b/a2-051/draft-runs',
    [string]$ExpectedBaseVersion = '1.1.6',
    [string]$ExpectedArchiveSha256 = '92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8',
    [string]$CandidateVersion = '0.5.1',
    [switch]$SkipHost
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'IFX050.Tooling.psm1') -Force
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { Get-IFX050Sha256 $Path }
function TextHash([string]$Text) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant() }
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }
function Fingerprint([string]$Root) { @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object { "$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)" }) -join "`n" }
function Stage([string]$Dir) {
    $o = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'Invoke-IFX050EvidenceProducers.ps1') -Phase Stage -TargetRoot $target -RunRecordPath (Full $ProductionRecord) -EvidenceRoot $Dir 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Evidence staging failed: $($o -join ' ')"
}
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$target = if ($TargetRoot) { Full $TargetRoot } else { $repo }
$commit = (& git -C $target rev-parse HEAD).Trim(); Assert ($LASTEXITCODE -eq 0) 'Target commit unavailable.'
$inventoryFull = Full $InventoryPath; $inventory = Get-Content $inventoryFull -Raw | ConvertFrom-Json -Depth 100
Assert ($inventory.status -ceq 'pass' -and $inventory.scope -ceq 'ifx-050a-source-module-claim-inventory' -and @($inventory.modules).Count -eq 37 -and @($inventory.rules).Count -eq 83 -and $inventory.claimCount -eq 79) '0.5.0-a inventory drift.'
Assert ($inventory.sourceCommit -ceq (& git -C $repo rev-parse HEAD).Trim()) 'The inventory must be taken at the harness HEAD.'
$production = Get-Content (Full $ProductionRecord) -Raw | ConvertFrom-Json -Depth 20
Assert ($production.status -ceq 'pass' -and $production.targetCommit -ceq $commit) 'The production record must pass at the Target commit.'
$archive = Full $BaseArchivePath; Assert ((Hash $archive) -ceq $ExpectedArchiveSha256) 'Published archive drift.'
$receipt = Get-Content $BaseReceiptPath -Raw | ConvertFrom-Json -Depth 100
Assert ($receipt.version -ceq $ExpectedBaseVersion -and $receipt.archiveSha256 -ceq (Hash $archive)) 'Published receipt drift.'
$basePackage = Join-Path $BaseInstallRoot 'package'
$baseCheck = & pwsh -NoProfile -File (Join-Path $basePackage 'core/runtime/Test-V4Package.ps1') -PackageRoot $basePackage | ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.status -ceq 'pass' -and $baseCheck.packageHash -ceq $inventory.basePackageHash) 'Published Package drift.'
$spec = Get-IFX050Spec
$profile044Path = Get-IFX050Baseline044Path 'profile.json'
$profile044 = Get-Content $profile044Path -Raw | ConvertFrom-Json -AsHashtable -Depth 100
Assert ($profile044.version -ceq '0.4.4' -and @($profile044.moduleSelections).Count -eq 37) '0.4.4 Profile drift.'

# Profile 0.5.0.
$selections = [Collections.Generic.List[object]]::new(); $changedIds = [Collections.Generic.List[string]]::new()
foreach ($selection in $profile044.moduleSelections) {
    $row = @($spec.modules | Where-Object { $_.id -ceq $selection.id })[0]
    if ($row.disposition -contains 'unchanged') { $selections.Add([ordered]@{ id = $selection.id; versionRange = $selection.versionRange; config = $selection.config }); continue }
    $changedIds.Add($selection.id)
    $selections.Add([ordered]@{ id = $selection.id; versionRange = $selection.versionRange; config = (New-IFX050ModuleConfig $selection.id -TargetRoot $target) })
}
Assert ($changedIds.Count -eq 25) 'Changed module count drift.'
$profile = [ordered]@{ formatVersion = 1; id = 'ifx_profile'; version = $CandidateVersion; projectIdentity = $profile044.projectIdentity; moduleSelections = @($selections.ToArray()); stageConfiguration = $profile044.stageConfiguration; rules = $profile044.rules; baselineRefs = @(); workspaceEvidence = $profile044.workspaceEvidence }

$runId = [guid]::NewGuid().ToString('N'); $runRoot = Join-Path ([IO.Path]::GetTempPath()) "ifx-050-bundle-$runId"
$bundle = Join-Path $runRoot 'bundle'; $package = Join-Path $bundle 'package'; [void][IO.Directory]::CreateDirectory((Join-Path $package 'modules'))
$external = [Collections.Generic.List[object]]::new(); $ceilingRows = [Collections.Generic.List[object]]::new()
foreach ($entry in $inventory.modules) {
    $id = [string]$entry.id; if ($id -ceq 'architecture-conformance') { continue }
    $source = Join-Path $repo $entry.sourcePath; $manifestPath = Join-Path $source 'module.json'
    Assert ((Hash $manifestPath) -ceq $entry.manifestSha256 -and (Hash (Join-Path $source 'adapter.ps1')) -ceq $entry.adapterSha256 -and (Hash (Join-Path $source 'dependencies.lock.json')) -ceq $entry.dependencyLockSha256) "Module byte drift: $id"
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -Depth 100
    $selection = @($selections | Where-Object { $_.id -ceq $id }); Assert ($selection.Count -eq 1) "Missing Profile selection: $id"
    Assert (Test-Json -Json ($selection[0].config | ConvertTo-Json -Depth 100 -Compress) -SchemaFile (Join-Path $source 'config.schema.json') -ErrorAction Stop) "Config schema drift: $id"
    $dest = Join-Path $package "modules/$id"; Copy-Item -LiteralPath $source -Destination $dest -Recurse
    $cap = $manifest.capabilities
    $ceiling = [ordered]@{ readRoots = @($cap.readRoots); writeRoots = @($cap.writeRoots); processes = @($cap.processes); network = [bool]$cap.network; maxTimeoutSeconds = [int]$cap.timeoutSeconds }
    Assert ($ceiling.writeRoots.Count -eq 0 -and -not $ceiling.network) "Unsafe capability: $id"
    $external.Add([ordered]@{ id = $id; version = $manifest.version; manifestPath = "modules/$id/module.json"; manifestSha256 = Hash (Join-Path $dest 'module.json'); allowedCapabilities = $ceiling })
    $ceilingRows.Add([ordered]@{ moduleId = $id; allowedCapabilities = $ceiling })
}
Assert ($external.Count -eq 36) 'External manifest module count drift.'
$profilePath = Join-Path $package 'profiles/catalog/ifx_profile/profile.json'; Write-IFX050Json $profilePath $profile
Assert (Test-Json -LiteralPath $profilePath -SchemaFile (Join-Path $basePackage 'core/contracts/profile.schema.json') -ErrorAction Stop) 'Profile schema drift.'
Assert ($profile.moduleSelections.Count -eq 37 -and @($profile.stageConfiguration.pre.modules).Count -eq 10 -and @($profile.stageConfiguration.post.modules).Count -eq 27 -and @($profile.rules).Count -eq 80) 'Profile cardinality drift.'
$profileText = [IO.File]::ReadAllText($profilePath)
Assert ($profileText -notmatch 'evidenceLock(Path|Sha256)') 'The 0.5.0 Profile must not name an evidence lock.'
Copy-Item -LiteralPath $inventoryFull -Destination (Join-Path $package 'profiles/catalog/ifx_profile/authority-map.json')
$producers = @($spec.modules | Where-Object { $null -ne $_.lockBinding } | ForEach-Object {
    $lb = $_.lockBinding; [ordered]@{ gate = $lb.gate; moduleId = $_.id; producerId = $lb.producerId; script = $lb.script; scriptSha256 = Get-IFX050PinSha256 (Join-Path $repo $lb.script); freshness = $lb.freshness } })
Write-IFX050Json (Join-Path $package 'profiles/catalog/ifx_profile/evidence-lineage.json') ([ordered]@{ formatVersion = 1; sourceCommit = $commit; ordinalInventorySha256 = Hash $inventoryFull; changeSpecSha256 = Hash (Join-Path $PSScriptRoot 'change-spec.json')
    evidenceModel = 'staged-by-workflow'; stagingManifest = 'EvidenceRoot/locks/staging.json'; stagingScript = 'docs/guards/candidates/ifx-i2b-051/Invoke-IFX050EvidenceProducers.ps1'; producers = $producers
    g04Status = 'PRE-READY'; g04BlockerCount = 7; p103Deferred = @('G05-Phase9-eight', 'v3-pre-diff', 'v3-cross-platform-ubuntu-latest', 'v3-cross-platform-windows-latest') })
$files = @(Get-ChildItem -LiteralPath $package -File -Recurse | Sort-Object FullName | ForEach-Object { [ordered]@{ path = [IO.Path]::GetRelativePath($package, $_.FullName).Replace('\', '/'); sha256 = Hash $_.FullName; size = $_.Length } })
$manifestPath = Join-Path $bundle 'bundle-manifest.json'
Write-IFX050Json $manifestPath ([ordered]@{ formatVersion = 1; id = 'ifx-profile-candidate'; version = $CandidateVersion; compatibleApi = '1.x'; baseVersion = $ExpectedBaseVersion; profiles = @([ordered]@{ id = 'ifx_profile'; version = $CandidateVersion; path = 'profiles/catalog/ifx_profile/profile.json'; sha256 = Hash $profilePath }); modules = @($external.ToArray()); files = $files })
$reviewPath = Join-Path $runRoot 'synthetic-review.json'
Write-IFX050Json $reviewPath ([ordered]@{ formatVersion = 1; id = "20260929-ifx-$($CandidateVersion.Replace('.','-'))-synthetic-fixture"; scope = 'synthetic-test-only'; decision = 'accepted'; acceptedBy = [ordered]@{ authorityType = 'test-fixture'; authorityId = 'ifx-050a-synthetic-fixture'; candidateHostVerdictAllowed = $false }; bundleManifestSha256 = Hash $manifestPath; baseArchiveSha256 = Hash $archive; moduleCeilings = @($ceilingRows.ToArray()) })
$state = Join-Path $runRoot 'compose-state'; $composeEvidence = Join-Path $runRoot 'compose-evidence'; [void][IO.Directory]::CreateDirectory($state); [void][IO.Directory]::CreateDirectory($composeEvidence)
$composed = Join-Path $runRoot 'composed'; $compositionReceipt = Join-Path $runRoot 'composition.receipt.json'
$compose = @(& pwsh -NoProfile -File (Join-Path $basePackage 'core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archive -BundleRoot $bundle -ReviewRecordPath $reviewPath -OutputInstallRoot $composed -CompositionReceiptPath $compositionReceipt -TargetRoot $target -StateRoot $state -EvidenceRoot $composeEvidence -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Synthetic composition failed: $($compose -join ' ')"
$verify = @(& pwsh -NoProfile -File (Join-Path $basePackage 'core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $compositionReceipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0 -and (($verify -join "`n") | ConvertFrom-Json).status -ceq 'pass') 'Synthetic composition receipt failed.'
$packageBefore = Fingerprint (Join-Path $composed 'package')
$targetTrackedBefore = @(& git -C $target status --porcelain --untracked-files=no) -join "`n"

$cases = [Collections.Generic.List[object]]::new()
$hostEvidence = Join-Path $runRoot 'host-evidence'; Stage $hostEvidence
function Invoke-Host([string]$Stage, [string]$Evidence, [switch]$Dependencies, [string]$Label, [string]$PackageRoot = (Join-Path $composed 'package'), [string]$HostDll = (Join-Path $composed 'host/v4-guards.dll')) {
    $hostState = Join-Path $runRoot "host-state-$Label"; [void][IO.Directory]::CreateDirectory($hostState)
    $a = @($HostDll, 'stage', 'run', '--stage', $Stage, '--package-root', $PackageRoot, '--target-root', $target, '--state-root', $hostState, '--evidence-root', $Evidence, '--profile', 'ifx_profile')
    if ($Dependencies) { $a += '--with-dependencies' }
    $lines = @(& dotnet @a 2>&1); $raw = $lines -join "`n"; $exit = $LASTEXITCODE
    try { $result = $raw | ConvertFrom-Json -Depth 100 } catch { throw "Non-JSON Host $Label`: $raw" }
    [pscustomobject]@{ exit = $exit; result = $result; raw = $raw }
}
if (-not $SkipHost) {
    foreach ($h in @([ordered]@{ id = 'direct-pre'; stage = 'pre'; count = 10; claims = 22; dependencies = $false }, [ordered]@{ id = 'direct-post'; stage = 'post'; count = 27; claims = 57; dependencies = $false }, [ordered]@{ id = 'dependency-post'; stage = 'post'; count = 37; claims = 79; dependencies = $true })) {
        $r = Invoke-Host $h.stage $hostEvidence -Dependencies:$h.dependencies $h.id; $result = $r.result
        Assert ($r.exit -eq 0 -and $result.status -ceq 'pass' -and @($result.moduleResults).Count -eq $h.count -and @($result.coverage).Count -eq $h.claims -and @($result.findings).Count -eq 0) "Integrated Host failed $($h.id): $($r.raw)"
        Assert (@($result.coverage | Where-Object { $_.matched -lt $_.minimum }).Count -eq 0) "Vacuous coverage $($h.id)."
        $expectedStages = if ($h.dependencies) { 'bootstrap,analysis,pre,post' } else { $h.stage }
        Assert ((@($result.executedStages) -join ',') -ceq $expectedStages) "Unexpected stage order $($h.id)."
        $cases.Add([ordered]@{ id = $h.id; status = 'pass'; moduleCount = $h.count; claimCount = $h.claims; stages = @($result.executedStages) })
    }
}
$negativeCases = [Collections.Generic.List[object]]::new()
function Variant([string]$Id, [string]$Kind) {
    $negativeBundle = Join-Path $runRoot "negative-$Id-bundle"; Copy-Item -LiteralPath $bundle -Destination $negativeBundle -Recurse
    $negativeManifestPath = Join-Path $negativeBundle 'bundle-manifest.json'
    if ($Kind -ceq 'tampered-manifest') { $bad = Get-Content $negativeManifestPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100; $bad.profiles[0].sha256 = ('0' * 64); Write-IFX050Json $negativeManifestPath $bad }
    else {
        $negativeProfilePath = Join-Path $negativeBundle 'package/profiles/catalog/ifx_profile/profile.json'
        $badProfile = Get-Content $negativeProfilePath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        if ($Kind -ceq 'baseline') { $badProfile.baselineRefs = @('baselines/undeclared-050a.json') } else { throw "Unknown negative variant: $Kind" }
        Write-IFX050Json $negativeProfilePath $badProfile
        $bad = Get-Content $negativeManifestPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $bad.profiles[0].sha256 = Hash $negativeProfilePath
        $entry = @($bad.files | Where-Object { $_.path -ceq 'profiles/catalog/ifx_profile/profile.json' }); $entry[0].sha256 = Hash $negativeProfilePath; $entry[0].size = (Get-Item $negativeProfilePath).Length
        Write-IFX050Json $negativeManifestPath $bad
    }
    $negativeReview = Join-Path $runRoot "negative-$Id-review.json"
    $reviewCopy = Get-Content $reviewPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100; $reviewCopy.id = "20260929-ifx-050a-$Id-synthetic-fixture"; $reviewCopy.bundleManifestSha256 = Hash $negativeManifestPath; Write-IFX050Json $negativeReview $reviewCopy
    $negativeInstall = Join-Path $runRoot "negative-$Id-composed"; $negativeReceipt = Join-Path $runRoot "negative-$Id-receipt.json"
    $null = @(& pwsh -NoProfile -File (Join-Path $basePackage 'core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archive -BundleRoot $negativeBundle -ReviewRecordPath $negativeReview -OutputInstallRoot $negativeInstall -CompositionReceiptPath $negativeReceipt -TargetRoot $target -StateRoot $state -EvidenceRoot $composeEvidence -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -ne 0 -and -not (Test-Path $negativeInstall)) "Negative $Id composition unexpectedly passed."
    $negativeCases.Add([ordered]@{ id = $Id; status = 'blocked'; phase = 'composition' })
}
Variant 'manifest-tamper' 'tampered-manifest'
Variant 'baseline-injection' 'baseline'
if (-not $SkipHost) {
    # Post without the staged evidence: the lock consumers fail closed; nothing in the Profile can stand in for it.
    $unstaged = Join-Path $runRoot 'host-evidence-unstaged'; [void][IO.Directory]::CreateDirectory($unstaged)
    Copy-Item -LiteralPath (Join-Path $hostEvidence 'assembly-manifest.json') -Destination (Join-Path $unstaged 'assembly-manifest.json')
    Copy-Item -LiteralPath (Join-Path $hostEvidence 'assemblies') -Destination (Join-Path $unstaged 'assemblies') -Recurse
    $r = Invoke-Host 'post' $unstaged 'missing-staged-evidence'
    $lockModules = @($spec.modules | Where-Object { $null -ne $_.lockBinding } | ForEach-Object { $_.id })
    Assert ($r.exit -ne 0 -and $r.result.status -ceq 'error' -and $r.result.exitCategory -ceq 'prerequisite-missing') "Missing staged evidence did not block Post: $($r.raw)"
    $negativeCases.Add([ordered]@{ id = 'missing-staged-evidence'; status = 'blocked'; phase = 'host'; category = $r.result.exitCategory; lockConsumers = $lockModules })
}
$targetTrackedAfter = @(& git -C $target status --porcelain --untracked-files=no) -join "`n"
Assert ((Fingerprint (Join-Path $composed 'package')) -ceq $packageBefore -and $targetTrackedAfter -ceq $targetTrackedBefore) 'Package or tracked TargetRoot bytes changed.'
$receiptObject = Get-Content $compositionReceipt -Raw | ConvertFrom-Json -Depth 100
# The receipt without its timestamps and paths: two builds of the same inputs must agree (A1-5 determinism).
$receiptProjection = [ordered]@{ formatVersion = $receiptObject.formatVersion; kind = $receiptObject.kind; status = $receiptObject.status; productVersion = $receiptObject.productVersion; packageHash = $receiptObject.packageHash; baseArchiveSha256 = $receiptObject.baseArchiveSha256; baseReceiptSha256 = $receiptObject.baseReceiptSha256; bundleManifestSha256 = $receiptObject.bundleManifestSha256; reviewRecordSha256 = $receiptObject.reviewRecordSha256; files = @($receiptObject.files) }
$report = Join-Path (Full $EvidenceRoot) $runId; [void][IO.Directory]::CreateDirectory($report)
Copy-Item -LiteralPath $bundle -Destination (Join-Path $report 'bundle') -Recurse
Copy-Item -LiteralPath $reviewPath -Destination (Join-Path $report 'synthetic-review.json')
Copy-Item -LiteralPath $compositionReceipt -Destination (Join-Path $report 'composition.receipt.json')
Write-IFX050Json (Join-Path $report 'summary.json') ([ordered]@{ formatVersion = 1; status = $(if ($SkipHost) { 'partial' } else { 'pass' }); scope = 'ifx-050a-candidate-bundle'; hostValidated = [bool](-not $SkipHost); baseVersion = $ExpectedBaseVersion; bundleVersion = $CandidateVersion; targetCommit = $commit; sourceCommit = $commit
    workspaceEvidenceDeclared = ($null -ne $profile.workspaceEvidence); evidenceModel = 'staged-by-workflow'
    moduleSelections = 37; changedModules = 25; externalModules = 36; distinctClaims = 79; baselineRefs = @(); cases = @($cases.ToArray()); negativeCases = @($negativeCases.ToArray())
    bundleManifestSha256 = Hash $manifestPath; profileSha256 = Hash $profilePath; ordinalInventorySha256 = Hash $inventoryFull; productionRecordSha256 = Hash (Full $ProductionRecord); compositionReceiptSha256 = Hash $compositionReceipt; compositionReceiptProjectionSha256 = TextHash (($receiptProjection | ConvertTo-Json -Depth 100 -Compress)); composedPackageFingerprintSha256 = TextHash $packageBefore
    limitations = @('Synthetic composition is not Xiaolong Feng approval.', 'C6c dual-platform and independent negative certification remain required.', 'G04 PRE-READY and P10.3 deferrals remain open.') })
Write-Output "IFX 0.5.0 candidate bundle passed: $report"
