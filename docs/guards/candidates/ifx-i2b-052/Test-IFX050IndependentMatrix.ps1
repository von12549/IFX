# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-4: the independent matrix of the
# ifx_profile 0.5.0 candidate; successor of candidates/ifx-rebind-116/Test-IFX116IndependentMatrix.ps1 (unchanged).
# The bundle is composed on the published 1.1.6 base and every adapter call runs the composed bytes. Sources:
# - the 25 changed modules: their suites (Test-IFX050Module.ps1, capture mode) on a clean Target clone at HEAD, with
#   evidence produced once on that clone (Invoke-IFX050EvidenceProducers.ps1) and staged per case; the lock consumers
#   run first because the type and graph locks live one hour;
# - the 11 unchanged IFX modules: their 0.4.4 suites through the I1 instrumented wrapper (transcribed below);
# - the unchanged residual cases and architecture-conformance: Test-IFX050SupplementalFixtures.ps1.
# The captures are classified by IFX050.Matrix.psm1 against matrix-contract-050.json: 191 core cases, no gap.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InventoryPath,
    [Parameter(Mandatory)][string]$BundleRoot,
    [Parameter(Mandatory)][string]$ReviewRecordPath,
    [Parameter(Mandatory)][ValidateSet('windows', 'linux')][string]$Platform,
    # A clean checkout of HEAD that the suites may edit and restore; cloned from the repository when absent.
    [string]$TargetRoot,
    # Producer runs on TargetRoot (Invoke-IFX050EvidenceProducers.ps1 -Phase Produce); produced when absent.
    [string]$ProductionRecord,
    [string]$BaseInstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6',
    [string]$BaseReceiptPath = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.6.install.json',
    [string]$BaseArchivePath = 'artifacts/guards/p10-ifx-116/base-archive/v4-guards-1.1.6.zip',
    [string]$EvidenceRoot = 'artifacts/guards/p10-ifx-i2b/a3-052/matrix-runs',
    [string]$MatrixContractPath = 'docs/guards/candidates/ifx-i2b-052/matrix-contract-050.json',
    [string]$MatrixContractVerifierPath = 'docs/guards/candidates/ifx-i2b-052/Test-IFX050MatrixContract.ps1',
    [string]$ExpectedBaseVersion = '1.1.6',
    [string]$ExpectedArchiveSha256 = '92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8',
    [string]$ExpectedPackageHash = 'a09469f77956190fbffa827ff5b7da2a63b615d66bf47a86ad0d17c7207bc825',
    [string]$CandidateVersion = '0.5.2',
    [string]$ReportPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../ifx-rebind-116/IFX116.V4Reference.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'IFX050.Tooling.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'IFX050.Matrix.psm1') -Force
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function WriteJson([string]$Path, $Value) { Write-IFX050Json $Path $Value }
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }
function Fingerprint([string]$Root) { @((Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object { "$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)" })) -join "`n" }
function AddGap([string]$Id, [string]$Reason) { $gaps.Add([ordered]@{ id = $Id; reason = $Reason }) }
function Run-Suite([string]$Id, [string]$ModuleId, [string]$Script, [string[]]$Arguments, [int]$ReviewedTimeoutSeconds, [string]$Mode) {
    $log = Join-Path $runRoot "suites/$Id.output.txt"; $capture = Join-Path $runRoot "captures/$Id.jsonl"
    $started = [DateTimeOffset]::UtcNow; $watch = [Diagnostics.Stopwatch]::StartNew()
    $output = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $Script @Arguments 2>&1); $code = $LASTEXITCODE; $watch.Stop()
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($log)); [IO.File]::WriteAllText($log, (($output -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
    $suiteResults.Add([ordered]@{ id = $Id; moduleId = $ModuleId; mode = $Mode; script = [IO.Path]::GetRelativePath($repo, $Script).Replace('\', '/'); scriptSha256 = Hash $Script
        startedAt = $started.ToString('o'); completedAt = [DateTimeOffset]::UtcNow.ToString('o'); elapsedSeconds = [math]::Round($watch.Elapsed.TotalSeconds, 3); reviewedTimeoutSeconds = $ReviewedTimeoutSeconds
        exitCode = $code; status = $(if ($code -eq 0) { 'pass' } else { 'error' }); capturePath = "captures/$Id.jsonl"; outputPath = "suites/$Id.output.txt" })
    if (Test-Path -LiteralPath $capture) { $captureFiles.Add($capture) }
}

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$commit = (& git -C $repo rev-parse HEAD).Trim(); Assert ($LASTEXITCODE -eq 0) 'Git commit unavailable.'
$trackedBefore = @(& git -C $repo status --porcelain --untracked-files=no); Assert ($LASTEXITCODE -eq 0 -and ($trackedBefore -join '').Trim().Length -eq 0) 'Tracked source must be clean.'
$inventoryFull = Full $InventoryPath; $bundleFull = Full $BundleRoot; $reviewFull = Full $ReviewRecordPath
$baseInstall = Full $BaseInstallRoot; $baseReceiptFull = Full $BaseReceiptPath; $archiveFull = Full $BaseArchivePath
$inventory = Get-Content $inventoryFull -Raw | ConvertFrom-Json -Depth 100
Assert ($inventory.status -ceq 'pass' -and $inventory.scope -ceq 'ifx-050a-source-module-claim-inventory' -and $inventory.sourceCommit -ceq $commit) 'The 0.5.0-a inventory must be regenerated on HEAD.'
Assert (@($inventory.modules).Count -eq 37 -and @($inventory.rules).Count -eq 83 -and $inventory.claimCount -eq 79) 'Inventory cardinality drift.'
$blocking = @($inventory.rules | Where-Object severity -CEQ 'blocking'); $advisory = @($inventory.rules | Where-Object severity -CEQ 'advisory')
Assert ($blocking.Count -eq 80 -and $advisory.Count -eq 3) 'Expected 80 blocking and three advisory rules.'
$changed = @($inventory.modules | Where-Object disposition -CEQ 'changed'); Assert ($changed.Count -eq 25) 'Changed module count drift.'
$manifestPath = Join-Path $bundleFull 'bundle-manifest.json'; $packageInBundle = Join-Path $bundleFull 'package'
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -Depth 100
Assert ($manifest.id -ceq 'ifx-profile-candidate' -and $manifest.version -ceq $CandidateVersion -and $manifest.baseVersion -ceq $ExpectedBaseVersion -and @($manifest.modules).Count -eq 36) 'Candidate bundle identity drift.'
foreach ($entry in $manifest.files) { $path = Join-Path $packageInBundle $entry.path; Assert ([IO.File]::Exists($path) -and (Hash $path) -ceq $entry.sha256 -and (Get-Item $path).Length -eq $entry.size) "Bundle file drift: $($entry.path)" }
Assert (@(Get-ChildItem $packageInBundle -File -Recurse).Count -eq @($manifest.files).Count) 'Bundle contains an unmanifested file.'
$review = Get-Content $reviewFull -Raw | ConvertFrom-Json -Depth 100
Assert ($review.scope -ceq 'synthetic-test-only' -and -not $review.acceptedBy.candidateHostVerdictAllowed -and $review.bundleManifestSha256 -ceq (Hash $manifestPath)) 'Synthetic review identity drift.'
Assert ((Hash $archiveFull) -ceq $ExpectedArchiveSha256) 'Published archive drift.'
$receipt = Get-Content $baseReceiptFull -Raw | ConvertFrom-Json -Depth 100
Assert ($receipt.version -ceq $ExpectedBaseVersion -and $receipt.archiveSha256 -ceq (Hash $archiveFull)) 'Published receipt drift.'

$runId = [guid]::NewGuid().ToString('N'); $runRoot = Join-Path (Full $EvidenceRoot) $runId
if ($ReportPath) { $reportFull = Full $ReportPath; $runRoot = [IO.Path]::GetDirectoryName($reportFull) } else { $reportFull = Join-Path $runRoot 'summary.json' }
Assert (-not (Test-Path $runRoot)) 'Matrix run root must be absent.'
[void][IO.Directory]::CreateDirectory($runRoot)
$contractFull = Full $MatrixContractPath; $contractVerifierFull = Full $MatrixContractVerifierPath; $contractReport = Join-Path $runRoot 'matrix-contract-summary.json'
$contractCheck = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $contractVerifierFull -RepositoryRoot $repo -BaseInstallRoot $baseInstall -InventoryPath $inventoryFull -ContractPath $contractFull -ReportPath $contractReport 2>&1)
Assert ($LASTEXITCODE -eq 0 -and [IO.File]::Exists($contractReport)) "Matrix contract failed: $($contractCheck -join "`n")"
$contract = Get-Content $contractFull -Raw | ConvertFrom-Json -Depth 100
$workRoot = Join-Path ([IO.Path]::GetTempPath()) "ifx052-m-$($runId.Substring(0,8))"; Assert (-not (Test-Path $workRoot)) 'Matrix work root must be absent.'
[void][IO.Directory]::CreateDirectory($workRoot)
$workBundle = Join-Path $workRoot 'bundle'; Copy-Item -LiteralPath $bundleFull -Destination $workBundle -Recurse
$workReview = Join-Path $workRoot 'synthetic-review.json'; Copy-Item -LiteralPath $reviewFull -Destination $workReview
$composeState = Join-Path $workRoot 'compose-state'; $composeEvidence = Join-Path $workRoot 'compose-evidence'; $composed = Join-Path $workRoot 'composed'; $compositionReceipt = Join-Path $workRoot 'composition.receipt.json'
[void][IO.Directory]::CreateDirectory($composeState); [void][IO.Directory]::CreateDirectory($composeEvidence)
$compose = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $baseInstall 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $baseInstall -BaseReceiptPath $baseReceiptFull -BaseArchivePath $archiveFull -BundleRoot $workBundle -ReviewRecordPath $workReview -OutputInstallRoot $composed -CompositionReceiptPath $compositionReceipt -TargetRoot $repo -StateRoot $composeState -EvidenceRoot $composeEvidence -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Candidate bundle composition failed: $($compose -join "`n")"
$verify = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $baseInstall 'package/core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $compositionReceipt -BaseReceiptPath $baseReceiptFull -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0 -and (($verify -join "`n") | ConvertFrom-Json).status -ceq 'pass') 'Candidate composition receipt failed.'
$package = Join-Path $composed 'package'; $profilePath = Join-Path $package 'profiles/catalog/ifx_profile/profile.json'; $profile = Get-Content $profilePath -Raw | ConvertFrom-Json -Depth 100
Assert (@($profile.moduleSelections).Count -eq 37 -and @($profile.stageConfiguration.pre.modules).Count -eq 10 -and @($profile.stageConfiguration.post.modules).Count -eq 27 -and @($profile.rules).Count -eq 80 -and @($profile.baselineRefs).Count -eq 0) 'Candidate Profile cardinality drift.'
Assert ([IO.File]::ReadAllText($profilePath) -notmatch 'evidenceLock(Path|Sha256)') 'The 0.5.0 Profile names an evidence lock.'
$lineage = Get-Content (Join-Path $package 'profiles/catalog/ifx_profile/evidence-lineage.json') -Raw | ConvertFrom-Json -Depth 100
Assert ($lineage.evidenceModel -ceq 'staged-by-workflow' -and $lineage.sourceCommit -ceq $commit -and $lineage.ordinalInventorySha256 -ceq (Hash $inventoryFull) -and @($lineage.producers).Count -eq 6) 'Candidate evidence lineage drift.'
foreach ($module in $inventory.modules) {
    $moduleRoot = Join-Path $package "modules/$($module.id)"; $moduleManifest = Join-Path $moduleRoot 'module.json'
    Assert ([IO.File]::Exists($moduleManifest) -and (Hash $moduleManifest) -ceq $module.manifestSha256) "Candidate module manifest drift: $($module.id)"
    if ($module.id -cne 'architecture-conformance') { Assert ((Hash (Join-Path $moduleRoot 'adapter.ps1')) -ceq $module.adapterSha256 -and (Hash (Join-Path $moduleRoot 'dependencies.lock.json')) -ceq $module.dependencyLockSha256) "Candidate module byte drift: $($module.id)" }
}

# The Target clone and its evidence.
if ($TargetRoot) { $target = Full $TargetRoot } else {
    $target = Join-Path $workRoot 'target'
    $o = @(& git clone --no-local --quiet -c core.longpaths=true $repo $target 2>&1); Assert ($LASTEXITCODE -eq 0) "Target clone failed: $($o -join ' ')"
}
Assert (((& git -C $target rev-parse HEAD) | Out-String).Trim() -ceq $commit) 'Target clone is not at HEAD.'
Assert (@(& git -C $target status --porcelain --untracked-files=all).Count -eq 0) 'Target clone must be clean.'
if ($ProductionRecord) { $productionFull = Full $ProductionRecord } else {
    $productionFull = Join-Path $runRoot 'production.json'
    $o = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot '../../v4-adoption/ci/Invoke-IFXEvidenceProducers.ps1') -Phase Produce -TargetRoot $target -RunRecordPath $productionFull 2>&1)
    [IO.File]::WriteAllText((Join-Path $runRoot 'production.output.txt'), (($o -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
    Assert ($LASTEXITCODE -eq 0) 'Evidence production failed; see production.output.txt.'
}
$production = Get-Content $productionFull -Raw | ConvertFrom-Json -Depth 20
Assert ($production.status -ceq 'pass' -and $production.targetCommit -ceq $commit) 'The production record must pass at HEAD.'

$packageBefore = Fingerprint $package; $suiteResults = [Collections.Generic.List[object]]::new(); $captureFiles = [Collections.Generic.List[string]]::new()
$ceiling = { param($Id) $c = @($review.moduleCeilings | Where-Object moduleId -CEQ $Id); Assert ($c.Count -eq 1) "Reviewed capability ceiling missing: $Id"; [int]$c[0].allowedCapabilities.maxTimeoutSeconds }

# 1. The 25 changed modules: lock consumers first (type and graph locks live one hour), then inventory order.
$spec = Get-IFX050Spec
$lockOrder = @('ifx-c1-type-provenance', 'ifx-c1-evaluated-reference', 'ifx-solution-evidence', 'ifx-assembly-evidence', 'ifx-frontend-evidence', 'ifx-database-evidence')
Assert ((@($spec.modules | Where-Object { $null -ne $_.lockBinding } | ForEach-Object id | Sort-Object) -join ',') -ceq (@($lockOrder | Sort-Object) -join ',')) 'Lock consumer set drift.'
$order = @($lockOrder) + @($changed | Sort-Object ordinal | ForEach-Object id | Where-Object { $lockOrder -cnotcontains $_ })
$moduleRunner = Join-Path $PSScriptRoot 'Test-IFX050Module.ps1'
foreach ($id in $order) {
    Run-Suite $id $id $moduleRunner @('-ModuleId', $id, '-CloneRoot', $target, '-EvidenceRoot', (Join-Path $runRoot "suites/$id"), '-ProductionRecord', $productionFull, '-SkipHost', '-PackageRoot', $package, '-CapturePath', (Join-Path $runRoot "captures/$id.jsonl"), '-BaseInstallRoot', $baseInstall, '-BaseReceiptPath', $baseReceiptFull, '-BaseArchivePath', $archiveFull) (& $ceiling $id) 'successor-suite-capture'
}

# 2. The 11 unchanged IFX modules: their 0.4.4 suites, redirected to the composed adapters by the I1 wrapper.
# IFX-V4-004: the suites' V4 schema lookups are redirected to the verified base package (pinned hashes).
$null = Assert-IFX116V4BaseReference -BaseInstallRoot $baseInstall; $v4ReferenceModule = Join-Path $PSScriptRoot '../ifx-rebind-116/IFX116.V4Reference.psm1'
$suiteSpecs = @(
    @('c1b', 'docs/guards/candidates/ifx-gate-coverage-c1b/tests/Test-IFXDomainReference.ps1'),
    @('c1c', 'docs/guards/candidates/ifx-gate-coverage-c1c/tests/Test-IFXPackageReference.ps1'),
    @('c1d', 'docs/guards/candidates/ifx-gate-coverage-c1d/tests/Test-IFXRingGraph.ps1'),
    @('c1e', 'docs/guards/candidates/ifx-gate-coverage-c1e/tests/Test-IFXOwnershipGraph.ps1'),
    @('c1f', 'docs/guards/candidates/ifx-gate-coverage-c1f/tests/Test-IFXProviderCycle.ps1'),
    @('c1g', 'docs/guards/candidates/ifx-gate-coverage-c1g/tests/Test-IFXEmbeddedAdapter.ps1'),
    @('c1h', 'docs/guards/candidates/ifx-gate-coverage-c1h/tests/Test-IFXSourcePolicy.ps1'),
    @('c1j', 'docs/guards/candidates/ifx-gate-coverage-c1j/tests/Test-IFXProjectName.ps1'),
    @('c1n', 'docs/guards/candidates/ifx-gate-coverage-c1n/tests/Test-IFXReferenceCycle.ps1'),
    @('c1o', 'docs/guards/candidates/ifx-gate-coverage-c1o/tests/Test-IFXInjection.ps1'),
    @('c5h', 'docs/guards/candidates/ifx-gate-coverage-c5h/tests/Test-IFXHistoricalIntegrity.ps1')
)
$unchangedIds = @($inventory.modules | Where-Object { $_.disposition -ceq 'unchanged' -and $_.id -cne 'architecture-conformance' } | ForEach-Object id)
Assert ($suiteSpecs.Count -eq 11 -and $unchangedIds.Count -eq 11) 'Unchanged suite catalog drift.'
$wrapperPath = Join-Path $workRoot 'Invoke-InstrumentedSuite.ps1'
$wrapper = @'
param([string]$TestScript,[string]$HarnessPath,[string]$ModuleId,[int]$ReviewedTimeoutSeconds,[string]$PackageRoot,[string]$RepositoryRoot,[string]$LogPath,[string]$EvidenceRoot,[string]$BaseInstallRoot,[string]$BaseReceiptPath,[string]$BaseArchivePath,[string]$RealEvidenceLockPath,[string]$SolutionLockPath,[string]$AssemblyLockPath,[string]$BaseVersion,[string]$BundleVersion,[string]$ArchiveSha256,[string]$PackageHash,[string]$V4ReferenceModulePath)
$ErrorActionPreference='Stop'
$global:C6MatrixFingerprintScript={param([string]$Root)if(-not(Test-Path $Root -PathType Container)){return '<absent>'};@((Get-ChildItem -LiteralPath $Root -File -Recurse -Force|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())"}))-join "`n"}
$global:C6MatrixTextHashScript={param([string]$Text)[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
$global:C6RealPwsh=@(Get-Command pwsh -CommandType Application)[0].Source
$global:C6PackageRoot=[IO.Path]::GetFullPath($PackageRoot);$global:C6RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot);$global:C6LogPath=[IO.Path]::GetFullPath($LogPath)
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($global:C6LogPath))
function global:pwsh {
    $actual=@($args);$fileIndex=[Array]::IndexOf($actual,'-File');$capture=$false;$requested=$null;$moduleId=$null
    if($fileIndex -ge 0 -and $fileIndex+1 -lt $actual.Count){$requested=[string]$actual[$fileIndex+1];$requestedName=[IO.Path]::GetFileName($requested);if($requestedName -ceq 'adapter.ps1'){$moduleId=[IO.Path]::GetFileName([IO.Path]::GetDirectoryName($requested));$replacement=Join-Path $global:C6PackageRoot "modules/$moduleId/adapter.ps1";if([IO.File]::Exists($replacement)){$actual[$fileIndex+1]=$replacement;$capture=[bool]$env:V4_STAGE_INPUT_JSON}}elseif($requestedName -ceq 'Invoke-IFXCompiledTypeEvidenceProducer.ps1'){if($actual -cnotcontains '-SolutionLockPath'){$actual+=@('-SolutionLockPath',$SolutionLockPath)};if($actual -cnotcontains '-AssemblyLockPath'){$actual+=@('-AssemblyLockPath',$AssemblyLockPath)}}}
    $inputJson=$env:V4_STAGE_INPUT_JSON;$targetRoot=$null;$before=$null;$inputCanonical=$null
    if($capture){$inputObject=$inputJson|ConvertFrom-Json -AsHashtable -Depth 100;$inputObject.packageRoot=$global:C6PackageRoot;$targetRoot=[IO.Path]::GetFullPath([string]$inputObject.targetRoot);$inputCanonical=$inputObject|ConvertTo-Json -Depth 100 -Compress;$env:V4_STAGE_INPUT_JSON=$inputCanonical;if($targetRoot -cne $global:C6RepositoryRoot){$before=& $global:C6MatrixFingerprintScript $targetRoot}}
    $output=@(& $global:C6RealPwsh @actual 2>&1);$code=$LASTEXITCODE
    if($capture){$after=if($targetRoot -cne $global:C6RepositoryRoot){& $global:C6MatrixFingerprintScript $targetRoot}else{'<repository-group>'};$record=[ordered]@{moduleId=$moduleId;requested=$requested;executed=[string]$actual[$fileIndex+1];targetRoot=$targetRoot;stage=$inputObject.stage;inputSha256=(& $global:C6MatrixTextHashScript $inputCanonical);fixtureSha256=(& $global:C6MatrixTextHashScript "$inputCanonical`n$before");exitCode=$code;targetBefore=$before;targetAfter=$after;output=($output-join "`n")};[IO.File]::AppendAllText($global:C6LogPath,(($record|ConvertTo-Json -Depth 100 -Compress)+"`n"),[Text.UTF8Encoding]::new($false));$env:V4_STAGE_INPUT_JSON=$inputJson}
    $global:LASTEXITCODE=$code;$output
}
$scriptToRun=$TestScript;$harnessAdjusted=$false;$source=Get-Content -LiteralPath $TestScript -Raw;$originalSource=$source;$timeoutMatch=[regex]::Match($source,'timeoutSeconds\s+-eq\s+(\d+)')
if($timeoutMatch.Success -and [int]$timeoutMatch.Groups[1].Value -ne $ReviewedTimeoutSeconds){$old=[int]$timeoutMatch.Groups[1].Value;$source=[regex]::Replace($source,"(timeoutSeconds\s+-eq\s+)$old\b",('${1}'+$ReviewedTimeoutSeconds));$source=[regex]::Replace($source,"(maxTimeoutSeconds\s*=\s*)$old\b",('${1}'+$ReviewedTimeoutSeconds))}
$source=$source.Replace('1.1.3',$BaseVersion).Replace('0.3.0',$BundleVersion).Replace('28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e',$ArchiveSha256).Replace('9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494',$PackageHash)
Import-Module $V4ReferenceModulePath -Force;$source=Convert-IFX116V4SchemaReferences -Source $source -BaseInstallRoot $BaseInstallRoot
if($source -cne $originalSource){$testDirectory=[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($TestScript)).Replace("'","''");$source=$source.Replace('$PSScriptRoot',"'$testDirectory'");[IO.File]::WriteAllText($HarnessPath,$source,[Text.UTF8Encoding]::new($false));$scriptToRun=$HarnessPath;$harnessAdjusted=$true}
$fixtureOnly=$originalSource -match "BaseInstallRoot\s*=\s*''"
$parameters=@{};$command=Get-Command $scriptToRun
if($command.Parameters.ContainsKey('EvidenceRoot')){$parameters.EvidenceRoot=$EvidenceRoot}
if(-not $fixtureOnly -and $command.Parameters.ContainsKey('BaseInstallRoot')){$parameters.BaseInstallRoot=$BaseInstallRoot}
if(-not $fixtureOnly -and $command.Parameters.ContainsKey('BaseReceiptPath')){$parameters.BaseReceiptPath=$BaseReceiptPath}
if(-not $fixtureOnly -and $command.Parameters.ContainsKey('BaseArchivePath')){$parameters.BaseArchivePath=$BaseArchivePath}
if($command.Parameters.ContainsKey('RealEvidenceLockPath')){$parameters.RealEvidenceLockPath=$RealEvidenceLockPath}
if($command.Parameters.ContainsKey('SolutionLockPath')){$parameters.SolutionLockPath=$SolutionLockPath}
if($command.Parameters.ContainsKey('AssemblyLockPath')){$parameters.AssemblyLockPath=$AssemblyLockPath}
& $scriptToRun @parameters
exit $LASTEXITCODE
'@
[IO.File]::WriteAllText($wrapperPath, $wrapper, [Text.UTF8Encoding]::new($false))
foreach ($s in $suiteSpecs) {
    $id = $s[0]; $script = Join-Path $repo $s[1]; $module = @($inventory.modules | Where-Object tranche -CEQ $id); Assert ($module.Count -eq 1 -and $unchangedIds -ccontains $module[0].id) "Suite-to-module mapping drift: $id"
    $harness = Join-Path $workRoot "harness/$id.ps1"; [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($harness))
    Run-Suite $id $module[0].id $wrapperPath @('-TestScript', $script, '-HarnessPath', $harness, '-ModuleId', $module[0].id, '-ReviewedTimeoutSeconds', [string](& $ceiling $module[0].id), '-PackageRoot', $package, '-RepositoryRoot', $repo, '-LogPath', (Join-Path $runRoot "captures/$id.jsonl"), '-EvidenceRoot', (Join-Path $runRoot "suites/$id"), '-BaseInstallRoot', $baseInstall, '-BaseReceiptPath', $baseReceiptFull, '-BaseArchivePath', $archiveFull, '-RealEvidenceLockPath', '', '-SolutionLockPath', '', '-AssemblyLockPath', '', '-BaseVersion', $ExpectedBaseVersion, '-BundleVersion', $CandidateVersion, '-ArchiveSha256', $ExpectedArchiveSha256, '-PackageHash', $ExpectedPackageHash, '-V4ReferenceModulePath', $v4ReferenceModule) (& $ceiling $module[0].id) 'accepted-044-suite-wrapper'
}

# 3. Unchanged residual cases and architecture-conformance.
Run-Suite 'supplemental' 'architecture-conformance' (Join-Path $PSScriptRoot 'Test-IFX050SupplementalFixtures.ps1') @('-PackageRoot', $package, '-RepositoryRoot', $repo, '-EvidenceRoot', (Join-Path $runRoot 'suites/supplemental'), '-CapturePath', (Join-Path $runRoot 'captures/supplemental.jsonl')) 180 'supplemental-fixtures'

# 4. Classification.
$captures = Read-IFX050Captures @($captureFiles.ToArray())
$gaps = [Collections.Generic.List[object]]::new()
$classified = Get-IFX050MatrixCases -Inventory $inventory -Contract $contract -Captures $captures
foreach ($g in @($classified.gaps)) { $gaps.Add($g) }
foreach ($suite in $suiteResults) { if ($suite.exitCode -ne 0) { AddGap "suite/$($suite.id)" 'Fresh suite failed; see suite output.' } }
$matrixArray = @($classified.cases)
if ($matrixArray.Count -lt 191) { AddGap 'matrix/cardinality' "Only $($matrixArray.Count) of 191 required core results were proven." }
Assert ((Fingerprint $package) -ceq $packageBefore) 'Composed PackageRoot changed during matrix.'
$trackedAfter = @(& git -C $repo status --porcelain --untracked-files=no); Assert ($LASTEXITCODE -eq 0 -and ($trackedAfter -join "`n") -ceq ($trackedBefore -join "`n")) 'Tracked repository changed during matrix.'
Assert (@(& git -C $target status --porcelain --untracked-files=all).Count -eq 0) 'Target clone was not restored.'
$caseManifestPath = Join-Path $runRoot 'case-manifest.json'; WriteJson $caseManifestPath ([ordered]@{ formatVersion = 1; sourceCommit = $commit; platform = $Platform; bundleManifestSha256 = Hash $manifestPath; cases = $matrixArray })
$status = if ($gaps.Count -eq 0 -and $matrixArray.Count -ge 191) { 'pass' } else { 'blocked' }
WriteJson $reportFull ([ordered]@{ formatVersion = 1; status = $status; scope = 'ifx-050a-independent-matrix'; platform = $Platform; sourceCommit = $commit; baseVersion = $ExpectedBaseVersion; bundleVersion = $CandidateVersion
    matrixContractSha256 = Get-IFX050PinSha256 $contractFull; matrixContractReportSha256 = Hash $contractReport; bundleManifestSha256 = Hash $manifestPath; profileSha256 = Hash $profilePath; inventorySha256 = Hash $inventoryFull; compositionReceiptSha256 = Hash $compositionReceipt
    productionRecordSha256 = Hash $productionFull; suiteCount = $suiteResults.Count; captureCount = $captures.Count; requiredCoreCases = 191; provenCoreCases = $matrixArray.Count; blockingRules = $blocking.Count; advisoryRules = $advisory.Count
    caseManifestPath = [IO.Path]::GetRelativePath($repo, $caseManifestPath).Replace('\', '/'); caseManifestSha256 = Hash $caseManifestPath; suites = @($suiteResults.ToArray()); gaps = @($gaps.ToArray()) })
if ($status -ceq 'pass') { Write-Output "IFX 0.5.0-a independent matrix passed: $reportFull"; exit 0 }
Write-Error "IFX 0.5.0-a independent matrix blocked with $($gaps.Count) gaps and $($matrixArray.Count)/191 proven cases. Report: $reportFull" -ErrorAction Continue
exit 1
