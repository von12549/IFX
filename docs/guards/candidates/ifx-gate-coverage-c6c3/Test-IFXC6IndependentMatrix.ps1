[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InventoryPath,
    [Parameter(Mandatory)][string]$BundleRoot,
    [Parameter(Mandatory)][string]$ReviewRecordPath,
    [Parameter(Mandatory)][ValidateSet('windows','linux')][string]$Platform,
    [string]$BaseInstallRoot='D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.3',
    [string]$BaseReceiptPath='D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.3.install.json',
    [string]$BaseArchivePath='artifacts/guards/p10-ifx-c3b/base-archive/v4-guards-1.1.3.zip',
    [string]$EvidenceRoot='artifacts/guards/p10-ifx-c6c3/matrix-runs',
    [string]$ReportPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function TextHash([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
function WriteJson([string]$Path,$Value){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))}
function Full([string]$Path){if([IO.Path]::IsPathFullyQualified($Path)){[IO.Path]::GetFullPath($Path)}else{[IO.Path]::GetFullPath((Join-Path $repo $Path))}}
function Fingerprint([string]$Root){@((Get-ChildItem -LiteralPath $Root -File -Recurse -Force|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"})) -join "`n"}
function AddGap([string]$Id,[string]$Reason){$gaps.Add([ordered]@{id=$Id;reason=$Reason})}
function Prop($Object,[string]$Name){
    if($null -eq $Object){return}
    $property=$Object.PSObject.Properties[$Name]
    if($null -eq $property){return}
    return $property.Value
}

$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$commit=(& git -C $repo rev-parse HEAD).Trim();Assert ($LASTEXITCODE -eq 0) 'Git commit unavailable.'
$trackedBefore=@(& git -C $repo status --porcelain --untracked-files=no);Assert ($LASTEXITCODE -eq 0 -and ($trackedBefore -join '').Trim().Length -eq 0) 'Tracked source must be clean.'
$inventoryFull=Full $InventoryPath;$bundleFull=Full $BundleRoot;$reviewFull=Full $ReviewRecordPath
$baseInstall=Full $BaseInstallRoot;$baseReceiptFull=Full $BaseReceiptPath;$archiveFull=Full $BaseArchivePath
$inventory=Get-Content $inventoryFull -Raw|ConvertFrom-Json -Depth 100
Assert ($inventory.status -ceq 'pass' -and $inventory.sourceCommit -ceq $commit) 'C6b0 inventory must be regenerated on HEAD.'
Assert (@($inventory.modules).Count -eq 37 -and @($inventory.rules).Count -eq 83 -and $inventory.claimCount -eq 79) 'C6b0 cardinality drift.'
$blocking=@($inventory.rules|Where-Object severity -CEQ 'blocking');$advisory=@($inventory.rules|Where-Object severity -CEQ 'advisory')
Assert ($blocking.Count -eq 80 -and $advisory.Count -eq 3) 'Expected 80 blocking and three advisory rules.'
$manifestPath=Join-Path $bundleFull 'bundle-manifest.json';$packageInBundle=Join-Path $bundleFull 'package'
$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json -Depth 100
Assert ($manifest.id -ceq 'ifx-profile-candidate' -and $manifest.version -ceq '0.3.0' -and $manifest.baseVersion -ceq '1.1.3' -and @($manifest.modules).Count -eq 36) 'Final bundle identity drift.'
foreach($entry in $manifest.files){$path=Join-Path $packageInBundle $entry.path;Assert ([IO.File]::Exists($path) -and (Hash $path) -ceq $entry.sha256 -and (Get-Item $path).Length -eq $entry.size) "Bundle file drift: $($entry.path)"}
Assert (@(Get-ChildItem $packageInBundle -File -Recurse).Count -eq @($manifest.files).Count) 'Bundle contains an unmanifested file.'
$review=Get-Content $reviewFull -Raw|ConvertFrom-Json -Depth 100
Assert ($review.scope -ceq 'synthetic-test-only' -and -not $review.acceptedBy.candidateHostVerdictAllowed -and $review.bundleManifestSha256 -ceq (Hash $manifestPath)) 'Synthetic review identity drift.'
Assert ((Hash $archiveFull) -ceq '28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e') 'Published archive drift.'
$receipt=Get-Content $baseReceiptFull -Raw|ConvertFrom-Json -Depth 100
Assert ($receipt.version -ceq '1.1.3' -and $receipt.archiveSha256 -ceq (Hash $archiveFull)) 'Published receipt drift.'

$runId=[guid]::NewGuid().ToString('N');$runRoot=Join-Path (Full $EvidenceRoot) $runId
if($ReportPath){$reportFull=Full $ReportPath;$runRoot=[IO.Path]::GetDirectoryName($reportFull)}else{$reportFull=Join-Path $runRoot 'summary.json'}
Assert (-not(Test-Path $runRoot)) 'Matrix run root must be absent.'
[void][IO.Directory]::CreateDirectory($runRoot)
$workRoot=Join-Path ([IO.Path]::GetTempPath()) "ifx-c6c3-$runId";Assert (-not(Test-Path $workRoot)) 'Matrix work root must be absent.'
[void][IO.Directory]::CreateDirectory($workRoot)
$workBundle=Join-Path $workRoot 'bundle';Copy-Item -LiteralPath $bundleFull -Destination $workBundle -Recurse
$workReview=Join-Path $workRoot 'synthetic-review.json';Copy-Item -LiteralPath $reviewFull -Destination $workReview
$composeState=Join-Path $workRoot 'compose-state';$composeEvidence=Join-Path $workRoot 'compose-evidence';$composed=Join-Path $workRoot 'composed';$compositionReceipt=Join-Path $workRoot 'composition.receipt.json'
[void][IO.Directory]::CreateDirectory($composeState);[void][IO.Directory]::CreateDirectory($composeEvidence)
$compose=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $baseInstall 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $baseInstall -BaseReceiptPath $baseReceiptFull -BaseArchivePath $archiveFull -BundleRoot $workBundle -ReviewRecordPath $workReview -OutputInstallRoot $composed -CompositionReceiptPath $compositionReceipt -TargetRoot $repo -StateRoot $composeState -EvidenceRoot $composeEvidence -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Final bundle composition failed: $($compose -join "`n")"
$verify=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $baseInstall 'package/core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $compositionReceipt -BaseReceiptPath $baseReceiptFull -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0 -and (($verify -join "`n")|ConvertFrom-Json).status -ceq 'pass') 'Final composition receipt failed.'
$package=Join-Path $composed 'package';$profilePath=Join-Path $package 'profiles/catalog/ifx_profile/profile.json';$profile=Get-Content $profilePath -Raw|ConvertFrom-Json -Depth 100
Assert (@($profile.moduleSelections).Count -eq 37 -and @($profile.stageConfiguration.pre.modules).Count -eq 10 -and @($profile.stageConfiguration.post.modules).Count -eq 27 -and @($profile.rules).Count -eq 80 -and @($profile.baselineRefs).Count -eq 0) 'Final Profile cardinality drift.'
$lineagePath=Join-Path $package 'profiles/catalog/ifx_profile/evidence-lineage.json';$lineage=Get-Content $lineagePath -Raw|ConvertFrom-Json -Depth 100
Assert ($lineage.sourceCommit -ceq $commit -and $lineage.ordinalInventorySha256 -ceq (Hash $inventoryFull) -and @($lineage.locks).Count -eq 7) 'Final evidence lineage drift.'
$lineageLockPaths=@{}
foreach($lock in $lineage.locks){$lockPath=Join-Path $repo $lock.path;Assert ([IO.File]::Exists($lockPath) -and (Hash $lockPath) -ceq $lock.sha256) "Final evidence lock drift: $($lock.id)";$lineageLockPaths[[string]$lock.id]=[string]$lock.path}
foreach($module in $inventory.modules){
    $moduleRoot=Join-Path $package "modules/$($module.id)";$moduleManifest=Join-Path $moduleRoot 'module.json'
    Assert ([IO.File]::Exists($moduleManifest) -and (Hash $moduleManifest) -ceq $module.manifestSha256) "Final module manifest drift: $($module.id)"
    if($module.id -cne 'architecture-conformance'){
        Assert ((Hash (Join-Path $moduleRoot 'adapter.ps1')) -ceq $module.adapterSha256 -and (Hash (Join-Path $moduleRoot 'dependencies.lock.json')) -ceq $module.dependencyLockSha256) "Final module byte drift: $($module.id)"
    }
}

$suiteSpecs=@(
    @('c1b','docs/guards/candidates/ifx-gate-coverage-c1b/tests/Test-IFXDomainReference.ps1'),
    @('c1c','docs/guards/candidates/ifx-gate-coverage-c1c/tests/Test-IFXPackageReference.ps1'),
    @('c1d','docs/guards/candidates/ifx-gate-coverage-c1d/tests/Test-IFXRingGraph.ps1'),
    @('c1e','docs/guards/candidates/ifx-gate-coverage-c1e/tests/Test-IFXOwnershipGraph.ps1'),
    @('c1f','docs/guards/candidates/ifx-gate-coverage-c1f/tests/Test-IFXProviderCycle.ps1'),
    @('c1g','docs/guards/candidates/ifx-gate-coverage-c1g/tests/Test-IFXEmbeddedAdapter.ps1'),
    @('c1h','docs/guards/candidates/ifx-gate-coverage-c1h/tests/Test-IFXSourcePolicy.ps1'),
    @('c1j','docs/guards/candidates/ifx-gate-coverage-c1j/tests/Test-IFXProjectName.ps1'),
    @('c1n','docs/guards/candidates/ifx-gate-coverage-c1n/tests/Test-IFXReferenceCycle.ps1'),
    @('c1o','docs/guards/candidates/ifx-gate-coverage-c1o/tests/Test-IFXInjection.ps1'),
    @('c1r1b','docs/guards/candidates/ifx-gate-coverage-c1r1b/tests/Test-IFXCompiledTypeEvidence.ps1'),
    @('c1r2b','docs/guards/candidates/ifx-gate-coverage-c1r2b/tests/Test-IFXEvaluatedGraphEvidence.ps1'),
    @('c2b1','docs/guards/candidates/ifx-gate-coverage-c2b1/tests/Test-IFXG03GovernanceCore.ps1'),
    @('c2b2','docs/guards/candidates/ifx-gate-coverage-c2b2/tests/Test-IFXG03CatalogSemantics.ps1'),
    @('c2c1','docs/guards/candidates/ifx-gate-coverage-c2c1/tests/Test-IFXG03SourceReconciliation.ps1'),
    @('c2c2','docs/guards/candidates/ifx-gate-coverage-c2c2/tests/Test-IFXG03Snapshots.ps1'),
    @('c2d','docs/guards/candidates/ifx-gate-coverage-c2d/tests/Test-IFXG03DocsCloseout.ps1'),
    @('c3b','docs/guards/candidates/ifx-gate-coverage-c3b/tests/Test-IFXG04Manifests.ps1'),
    @('c3c','docs/guards/candidates/ifx-gate-coverage-c3c/tests/Test-IFXG04Runtime.ps1'),
    @('c3d','docs/guards/candidates/ifx-gate-coverage-c3d/tests/Test-IFXG04Closeout.ps1'),
    @('c4a1','docs/guards/candidates/ifx-gate-coverage-c4a1/tests/Test-IFXPlan04Extraction.ps1'),
    @('c4a2','docs/guards/candidates/ifx-gate-coverage-c4a2/tests/Test-IFXPlan04Tenant.ps1'),
    @('c4a3','docs/guards/candidates/ifx-gate-coverage-c4a3/tests/Test-IFXPlan04Projection.ps1'),
    @('c4a4','docs/guards/candidates/ifx-gate-coverage-c4a4/tests/Test-IFXPlan04Abstractions.ps1'),
    @('c4b','docs/guards/candidates/ifx-gate-coverage-c4b/tests/Test-IFXDatabaseEvidence.ps1'),
    @('c4p0','docs/guards/candidates/ifx-gate-coverage-c4p0/tests/Test-IFXG05Inventory.ps1'),
    @('c4p1','docs/guards/candidates/ifx-gate-coverage-c4p1/tests/Test-IFXG05Protocol.ps1'),
    @('c4p2','docs/guards/candidates/ifx-gate-coverage-c4p2/tests/Test-IFXG05ExecutionHttp.ps1'),
    @('c4p4p5','docs/guards/candidates/ifx-gate-coverage-c4p4p5/tests/Test-IFXG05Carriers.ps1'),
    @('c4p6p7','docs/guards/candidates/ifx-gate-coverage-c4p6p7/tests/Test-IFXG05Governance.ps1'),
    @('c4p8p11','docs/guards/candidates/ifx-gate-coverage-c4p8p11/tests/Test-IFXG05Closeout.ps1'),
    @('c4s','docs/guards/candidates/ifx-gate-coverage-c4s/tests/Test-IFXPlan05Security.ps1'),
    @('c5b','docs/guards/candidates/ifx-gate-coverage-c5b/tests/Test-IFXSolutionEvidence.ps1'),
    @('c5c','docs/guards/candidates/ifx-gate-coverage-c5c/tests/Test-IFXAssemblyEvidence.ps1'),
    @('c5d','docs/guards/candidates/ifx-gate-coverage-c5d/tests/Test-IFXFrontendEvidence.ps1'),
    @('c5h','docs/guards/candidates/ifx-gate-coverage-c5h/tests/Test-IFXHistoricalIntegrity.ps1')
)
Assert ($suiteSpecs.Count -eq 36 -and @($suiteSpecs|ForEach-Object{$_[0]}|Sort-Object -Unique).Count -eq 36) 'Suite catalog drift.'
$wrapperPath=Join-Path $workRoot 'Invoke-InstrumentedSuite.ps1'
$wrapper=@'
param([string]$TestScript,[string]$HarnessPath,[string]$ModuleId,[int]$ReviewedTimeoutSeconds,[string]$PackageRoot,[string]$RepositoryRoot,[string]$LogPath,[string]$EvidenceRoot,[string]$BaseInstallRoot,[string]$BaseReceiptPath,[string]$BaseArchivePath,[string]$RealEvidenceLockPath,[string]$SolutionLockPath,[string]$AssemblyLockPath)
$ErrorActionPreference='Stop'
$global:C6MatrixFingerprintScript={param([string]$Root)if(-not(Test-Path $Root -PathType Container)){return '<absent>'};@((Get-ChildItem -LiteralPath $Root -File -Recurse -Force|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant())"}))-join "`n"}
$global:C6MatrixTextHashScript={param([string]$Text)[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
$global:C6RealPwsh=@(Get-Command pwsh -CommandType Application)[0].Source
$global:C6PackageRoot=[IO.Path]::GetFullPath($PackageRoot);$global:C6RepositoryRoot=[IO.Path]::GetFullPath($RepositoryRoot);$global:C6LogPath=[IO.Path]::GetFullPath($LogPath)
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($global:C6LogPath))
function global:pwsh {
    $actual=@($args);$fileIndex=[Array]::IndexOf($actual,'-File');$capture=$false;$requested=$null;$moduleId=$null
    if($fileIndex -ge 0 -and $fileIndex+1 -lt $actual.Count){$requested=[string]$actual[$fileIndex+1];$requestedName=[IO.Path]::GetFileName($requested);if($requestedName -ceq 'adapter.ps1'){$moduleId=[IO.Path]::GetFileName([IO.Path]::GetDirectoryName($requested));$replacement=Join-Path $global:C6PackageRoot "modules/$moduleId/adapter.ps1";if([IO.File]::Exists($replacement)){$actual[$fileIndex+1]=$replacement;$capture=[bool]$env:V4_STAGE_INPUT_JSON}}elseif($requestedName -ceq 'Invoke-IFXCompiledTypeEvidenceProducer.ps1'){$actual+=@('-SolutionLockPath',$SolutionLockPath,'-AssemblyLockPath',$AssemblyLockPath)}}
    $inputJson=$env:V4_STAGE_INPUT_JSON;$targetRoot=$null;$before=$null;$inputCanonical=$null
    if($capture){$inputObject=$inputJson|ConvertFrom-Json -AsHashtable -Depth 100;$inputObject.packageRoot=$global:C6PackageRoot;$targetRoot=[IO.Path]::GetFullPath([string]$inputObject.targetRoot);$inputCanonical=$inputObject|ConvertTo-Json -Depth 100 -Compress;$env:V4_STAGE_INPUT_JSON=$inputCanonical;if($targetRoot -cne $global:C6RepositoryRoot){$before=& $global:C6MatrixFingerprintScript $targetRoot}}
    $output=@(& $global:C6RealPwsh @actual 2>&1);$code=$LASTEXITCODE
    if($capture){$after=if($targetRoot -cne $global:C6RepositoryRoot){& $global:C6MatrixFingerprintScript $targetRoot}else{'<repository-group>'};$record=[ordered]@{moduleId=$moduleId;requested=$requested;executed=[string]$actual[$fileIndex+1];targetRoot=$targetRoot;stage=$inputObject.stage;inputSha256=(& $global:C6MatrixTextHashScript $inputCanonical);fixtureSha256=(& $global:C6MatrixTextHashScript "$inputCanonical`n$before");exitCode=$code;targetBefore=$before;targetAfter=$after;output=($output-join "`n")};[IO.File]::AppendAllText($global:C6LogPath,(($record|ConvertTo-Json -Depth 100 -Compress)+"`n"),[Text.UTF8Encoding]::new($false));$env:V4_STAGE_INPUT_JSON=$inputJson}
    $global:LASTEXITCODE=$code;$output
}
$scriptToRun=$TestScript;$harnessAdjusted=$false;$source=Get-Content -LiteralPath $TestScript -Raw;$timeoutMatch=[regex]::Match($source,'timeoutSeconds\s+-eq\s+(\d+)')
if($timeoutMatch.Success -and [int]$timeoutMatch.Groups[1].Value -ne $ReviewedTimeoutSeconds){$old=[int]$timeoutMatch.Groups[1].Value;$testDirectory=[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($TestScript)).Replace("'","''");$source=$source.Replace('$PSScriptRoot',"'$testDirectory'");$source=[regex]::Replace($source,"(timeoutSeconds\s+-eq\s+)$old\b",('${1}'+$ReviewedTimeoutSeconds));$source=[regex]::Replace($source,"(maxTimeoutSeconds\s*=\s*)$old\b",('${1}'+$ReviewedTimeoutSeconds));[IO.File]::WriteAllText($HarnessPath,$source,[Text.UTF8Encoding]::new($false));$scriptToRun=$HarnessPath;$harnessAdjusted=$true}
$fixtureOnly=$harnessAdjusted -or $source -match "BaseInstallRoot\s*=\s*''"
$parameters=@{};$command=Get-Command $scriptToRun
if($command.Parameters.ContainsKey('EvidenceRoot')){$parameters.EvidenceRoot=$EvidenceRoot}
if(-not $fixtureOnly -and $command.Parameters.ContainsKey('BaseInstallRoot')){$parameters.BaseInstallRoot=$BaseInstallRoot}
if(-not $fixtureOnly -and $command.Parameters.ContainsKey('BaseReceiptPath')){$parameters.BaseReceiptPath=$BaseReceiptPath}
if(-not $fixtureOnly -and $command.Parameters.ContainsKey('BaseArchivePath')){$parameters.BaseArchivePath=$BaseArchivePath}
if($command.Parameters.ContainsKey('RealEvidenceLockPath')){$parameters.RealEvidenceLockPath=$RealEvidenceLockPath}
& $scriptToRun @parameters
exit $LASTEXITCODE
'@
[IO.File]::WriteAllText($wrapperPath,$wrapper,[Text.UTF8Encoding]::new($false))
$packageBefore=Fingerprint $package;$suiteResults=[Collections.Generic.List[object]]::new();$captureFiles=[Collections.Generic.List[string]]::new()
foreach($spec in $suiteSpecs){
    $id=$spec[0];$script=Join-Path $repo $spec[1];$module=@($inventory.modules|Where-Object tranche -CEQ $id);Assert ($module.Count-eq1) "Suite-to-module mapping drift: $id";$reviewCeiling=@($review.moduleCeilings|Where-Object moduleId -CEQ $module[0].id);Assert ($reviewCeiling.Count-eq1) "Reviewed capability ceiling missing: $($module[0].id)";$capture=Join-Path $runRoot "captures/$id.jsonl";$suiteEvidence=Join-Path $runRoot "suites/$id";$suiteLog=Join-Path $runRoot "suites/$id.output.txt";$harness=Join-Path $workRoot "harness/$id.ps1"
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($harness));$realLock=switch($id){'c5b'{$lineageLockPaths.solution};'c5c'{$lineageLockPaths.assembly};'c5d'{$lineageLockPaths.frontend};default{''}}
    $output=@(& pwsh -NoLogo -NoProfile -NonInteractive -File $wrapperPath -TestScript $script -HarnessPath $harness -ModuleId $module[0].id -ReviewedTimeoutSeconds ([int]$reviewCeiling[0].allowedCapabilities.maxTimeoutSeconds) -PackageRoot $package -RepositoryRoot $repo -LogPath $capture -EvidenceRoot $suiteEvidence -BaseInstallRoot $baseInstall -BaseReceiptPath $baseReceiptFull -BaseArchivePath $archiveFull -RealEvidenceLockPath $realLock -SolutionLockPath $lineageLockPaths.solution -AssemblyLockPath $lineageLockPaths.assembly 2>&1);$code=$LASTEXITCODE
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($suiteLog));[IO.File]::WriteAllText($suiteLog,(($output-join "`n")+"`n"),[Text.UTF8Encoding]::new($false))
    $suiteResults.Add([ordered]@{id=$id;script=$spec[1];scriptSha256=Hash $script;reviewedTimeoutSeconds=[int]$reviewCeiling[0].allowedCapabilities.maxTimeoutSeconds;harnessAdjusted=[IO.File]::Exists($harness);harnessSha256=$(if([IO.File]::Exists($harness)){Hash $harness}else{$null});exitCode=$code;status=$(if($code-eq 0){'pass'}else{'error'});capturePath=[IO.Path]::GetRelativePath($runRoot,$capture).Replace('\','/');outputPath=[IO.Path]::GetRelativePath($runRoot,$suiteLog).Replace('\','/')})
    if(Test-Path $capture){$captureFiles.Add($capture)}
}

$captures=[Collections.Generic.List[object]]::new()
foreach($file in $captureFiles){foreach($line in Get-Content -LiteralPath $file){if(-not $line.Trim()){continue};$record=$line|ConvertFrom-Json -Depth 100;try{$result=$record.output|ConvertFrom-Json -Depth 100}catch{continue};$captures.Add([ordered]@{moduleId=$record.moduleId;fixtureId=[IO.Path]::GetFileName($record.targetRoot);fixtureSha256=$record.fixtureSha256;inputSha256=$record.inputSha256;processExit=[int]$record.exitCode;status=[string](Prop $result 'status');exitCategory=[string](Prop $result 'exitCategory');findings=@(Prop $result 'findings');coverage=@(Prop $result 'coverage');targetInvariant=($record.targetBefore -eq $null -or $record.targetBefore -ceq $record.targetAfter)})}}
$gaps=[Collections.Generic.List[object]]::new();$matrix=[Collections.Generic.List[object]]::new()
foreach($module in $inventory.modules){
    $id=[string]$module.id;$moduleRules=@($inventory.rules|Where-Object moduleId -CEQ $id);$blockingRules=@($moduleRules|Where-Object severity -CEQ 'blocking');$ownedClaims=@($blockingRules.claimId|Sort-Object -Unique);$rows=@($captures|Where-Object moduleId -CEQ $id)
    $clean=@($rows|Where-Object{$_.processExit-eq 0-and$_.status-ceq'pass'-and@($_.findings).Count-eq0-and@($_.coverage|Where-Object{$_.claimId-in$ownedClaims-and$_.matched-ge$_.minimum}).Count-eq$ownedClaims.Count-and$_.targetInvariant})
    if($clean.Count-eq0){AddGap "$id/C" 'No clean result with non-vacuous coverage for every owned blocking claim.'}else{$r=$clean[0];$matrix.Add([ordered]@{id="$id/C";kind='clean';moduleId=$id;ruleId=$null;claimIds=$ownedClaims;fixtureSha256=$r.fixtureSha256;expected=[ordered]@{processExit=0;status='pass';exitCategory='success'};actual=[ordered]@{processExit=$r.processExit;status=$r.status;exitCategory=$r.exitCategory};status='pass'})}
    $missing=@($rows|Where-Object{$_.processExit-eq0-and$_.status-ceq'error'-and$_.exitCategory-ceq'prerequisite-missing'-and@($_.findings).Count-eq0-and$_.targetInvariant})
    if($missing.Count-eq0){AddGap "$id/M" 'No prerequisite-missing result with zero findings.'}else{$r=$missing[0];$matrix.Add([ordered]@{id="$id/M";kind='missing';moduleId=$id;ruleId=$null;claimIds=$ownedClaims;fixtureSha256=$r.fixtureSha256;expected=[ordered]@{processExit=0;status='error';exitCategory='prerequisite-missing'};actual=[ordered]@{processExit=$r.processExit;status=$r.status;exitCategory=$r.exitCategory};status='pass'})}
    $zero=@($rows|Where-Object{$r=$_;if($r.processExit-ne0-or$r.status-cne'fail'-or$r.exitCategory-cne'findings-blocking'-or-not$r.targetInvariant){return $false};$zeroClaims=@($r.coverage|Where-Object{$_.claimId-in$ownedClaims-and$_.matched-eq0-and$_.minimum-gt0}|ForEach-Object claimId|Sort-Object -Unique);return (($zeroClaims-join ',')-ceq($ownedClaims-join ','))})
    if($zero.Count-eq0){AddGap "$id/Z" 'No zero-match result covering every owned blocking claim.'}else{$r=$zero[0];$matrix.Add([ordered]@{id="$id/Z";kind='zero';moduleId=$id;ruleId=$null;claimIds=$ownedClaims;fixtureSha256=$r.fixtureSha256;expected=[ordered]@{processExit=0;status='fail';exitCategory='findings-blocking';matched=0};actual=[ordered]@{processExit=$r.processExit;status=$r.status;exitCategory=$r.exitCategory};status='pass'})}
    foreach($rule in $blockingRules){
        $violations=@($rows|Where-Object{$r=$_;$blockingIds=@($r.findings|Where-Object{$_.ruleId-in@($blockingRules.ruleId)}|ForEach-Object ruleId|Sort-Object -Unique);$finding=@($r.findings|Where-Object ruleId -CEQ $rule.ruleId);$coverage=@($r.coverage|Where-Object{$_.claimId-ceq$rule.claimId-and$_.matched-gt0});$r.processExit-eq0-and$r.status-ceq'fail'-and$r.exitCategory-ceq'findings-blocking'-and$blockingIds.Count-eq1-and$blockingIds[0]-ceq$rule.ruleId-and$finding.Count-gt0-and@($finding|Where-Object{[string]$_.subject-and[string]$_.detectorId-and[string]$_.evidenceKind}).Count-eq$finding.Count-and$coverage.Count-eq1-and$r.targetInvariant})
        if($violations.Count-eq0){AddGap "$id/V/$($rule.ruleId)" "No independent blocking result for claim $($rule.claimId) with exact finding identity and nonzero coverage."}else{$r=$violations[0];$f=@($r.findings|Where-Object ruleId -CEQ $rule.ruleId)[0];$matrix.Add([ordered]@{id="$id/V/$($rule.ruleId)";kind='violation';moduleId=$id;ruleId=$rule.ruleId;claimIds=@($rule.claimId);fixtureSha256=$r.fixtureSha256;expected=[ordered]@{processExit=0;status='fail';exitCategory='findings-blocking'};actual=[ordered]@{processExit=$r.processExit;status=$r.status;exitCategory=$r.exitCategory;subject=$f.subject;detectorId=$f.detectorId;evidenceKind=$f.evidenceKind};status='pass'})}
    }
}
foreach($rule in $advisory){$rows=@($captures|Where-Object moduleId -CEQ $rule.moduleId);$advisoryFindings=@($rows|ForEach-Object{@($_.findings)}|Where-Object ruleId -CEQ $rule.ruleId);if($advisoryFindings.Count-eq0){AddGap "$($rule.moduleId)/A/$($rule.ruleId)" 'Advisory companion was not projected.'}}
foreach($suite in $suiteResults){if($suite.exitCode-ne0){AddGap "suite/$($suite.id)" 'Fresh instrumented suite failed; see suite output.'}}
if($matrix.Count-lt191){AddGap 'matrix/cardinality' "Only $($matrix.Count) of 191 required core results were proven."}
Assert ((Fingerprint $package) -ceq $packageBefore) 'Composed PackageRoot changed during matrix.'
$trackedAfter=@(& git -C $repo status --porcelain --untracked-files=no);Assert ($LASTEXITCODE-eq0-and($trackedAfter-join"`n")-ceq($trackedBefore-join"`n")) 'Tracked TargetRoot changed during matrix.'
$matrixArray=@($matrix.ToArray()|Sort-Object id);$caseManifestPath=Join-Path $runRoot 'case-manifest.json';WriteJson $caseManifestPath ([ordered]@{formatVersion=1;sourceCommit=$commit;platform=$Platform;bundleManifestSha256=Hash $manifestPath;cases=$matrixArray})
$status=if($gaps.Count-eq0-and$matrix.Count-ge191){'pass'}else{'blocked'}
$report=[ordered]@{formatVersion=1;status=$status;scope='c6c3-independent-matrix';platform=$Platform;sourceCommit=$commit;baseVersion='1.1.3';bundleManifestSha256=Hash $manifestPath;profileSha256=Hash $profilePath;inventorySha256=Hash $inventoryFull;compositionReceiptSha256=Hash $compositionReceipt;suiteCount=$suiteResults.Count;captureCount=$captures.Count;requiredCoreCases=191;provenCoreCases=$matrix.Count;blockingRules=$blocking.Count;advisoryRules=$advisory.Count;caseManifestPath=[IO.Path]::GetRelativePath($repo,$caseManifestPath).Replace('\','/');caseManifestSha256=Hash $caseManifestPath;suites=@($suiteResults.ToArray());gaps=@($gaps.ToArray())}
WriteJson $reportFull $report
if($status-ceq'pass'){Write-Output "IFX C6c3 independent matrix passed: $reportFull";exit 0}
Write-Error "IFX C6c3 independent matrix blocked with $($gaps.Count) gaps and $($matrix.Count)/191 proven cases. Report: $reportFull" -ErrorAction Continue
exit 1
