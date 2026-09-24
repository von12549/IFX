[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InventoryPath,
    [Parameter(Mandatory)][string]$SolutionLockPath,
    [Parameter(Mandatory)][string]$AssemblyLockPath,
    [Parameter(Mandatory)][string]$FrontendLockPath,
    [Parameter(Mandatory)][string]$DatabaseLockPath,
    [Parameter(Mandatory)][string]$TypeLockPath,
    [Parameter(Mandatory)][string]$GraphLockPath,
    [Parameter(Mandatory)][string]$GeneratedLockPath,
    [string]$BaseInstallRoot='D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.3',
    [string]$BaseReceiptPath='D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.3.install.json',
    [string]$BaseArchivePath='artifacts/guards/p10-ifx-c3b/base-archive/v4-guards-1.1.3.zip',
    [string]$EvidenceRoot='artifacts/guards/p10-ifx-c6b1/draft-runs',
    [switch]$SkipHost
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function WriteJson([string]$Path,$Value){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))}
function Rel([string]$Path){[IO.Path]::GetRelativePath($repo,$Path).Replace('\','/')}
function Full([string]$Path){if([IO.Path]::IsPathFullyQualified($Path)){[IO.Path]::GetFullPath($Path)}else{[IO.Path]::GetFullPath((Join-Path $repo $Path))}}
function Fingerprint([string]$Root){@(Get-ChildItem -LiteralPath $Root -File -Recurse -Force|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"}) -join "`n"}
function AddLock([string]$Id,[string]$Path,[string]$Gate,[int]$MaxSeconds){
    $full=Full $Path;Assert ([IO.File]::Exists($full)) "Missing $Id lock."
    $lock=Get-Content $full -Raw|ConvertFrom-Json -Depth 100 -DateKind String
    Assert ($lock.gate -ceq $Gate -and $lock.result -ceq 'passed') "Invalid $Id lock."
    $stamp=if($lock.PSObject.Properties.Name -contains 'createdAt'){[DateTimeOffset]::Parse([string]$lock.createdAt)}else{[DateTimeOffset]::Parse([string]$lock.completedAt)}
    Assert ($stamp -le [DateTimeOffset]::UtcNow.AddMinutes(5) -and $stamp -ge [DateTimeOffset]::UtcNow.AddSeconds(-$MaxSeconds)) "Expired $Id lock."
    if($lock.PSObject.Properties.Name -contains 'expiresAt'){Assert ([DateTimeOffset]::Parse([string]$lock.expiresAt) -gt [DateTimeOffset]::UtcNow) "Expired $Id lock."}
    Assert ($lock.targetCommit -ceq $commit) "Source commit drift in $Id lock."
    $locks[$Id]=[ordered]@{id=$Id;gate=$Gate;path=Rel $full;sha256=Hash $full;full=$full;content=$lock}
}
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$commit=(& git -C $repo rev-parse HEAD).Trim();Assert ($LASTEXITCODE -eq 0) 'Git commit unavailable.'
$inventoryFull=Full $InventoryPath;$inventory=Get-Content $inventoryFull -Raw|ConvertFrom-Json -Depth 100
Assert ($inventory.status -ceq 'pass' -and $inventory.sourceCommit -ceq $commit -and @($inventory.modules).Count -eq 37 -and @($inventory.rules).Count -eq 83 -and $inventory.claimCount -eq 79) 'C6b0 inventory drift.'
$archive=Full $BaseArchivePath;Assert ((Hash $archive) -ceq '28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e') 'Published archive drift.'
$receipt=Get-Content $BaseReceiptPath -Raw|ConvertFrom-Json -Depth 100
Assert ($receipt.version -ceq '1.1.3' -and $receipt.archiveSha256 -ceq (Hash $archive)) 'Published receipt drift.'
$basePackage=Join-Path $BaseInstallRoot 'package'
$baseCheck=& pwsh -NoProfile -File (Join-Path $basePackage 'core/runtime/Test-V4Package.ps1') -PackageRoot $basePackage|ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.status -ceq 'pass' -and $baseCheck.packageHash -ceq $inventory.basePackageHash) 'Published Package drift.'
$g04=Get-Content (Join-Path $repo 'docs/architecture/review/evidence/gates/G04/G04-phase12-status.json') -Raw|ConvertFrom-Json -Depth 100
Assert ($g04.status -ceq 'PRE-READY' -and @($g04.blockers).Count -eq 7 -and -not $g04.gateClosed -and -not $g04.approvalGranted) 'G04 governance drift.'
$locks=[ordered]@{}
AddLock 'solution' $SolutionLockPath 'Solution' 86400
AddLock 'assembly' $AssemblyLockPath 'Assembly' 86400
AddLock 'frontend' $FrontendLockPath 'Frontend' 86400
AddLock 'database' $DatabaseLockPath 'Database' 86400
AddLock 'type' $TypeLockPath 'C1CompiledTypeProvenance' 3600
AddLock 'graph' $GraphLockPath 'C1EvaluatedReferenceGraph' 3600
AddLock 'generated' $GeneratedLockPath 'C1GeneratedInputDisposition' 3600
Assert ($locks['generated'].content.sourceTreeSha256 -ceq $locks['solution'].content.sourceTreeSha256 -and $locks['generated'].content.solutionLockSha256 -ceq $locks['solution'].sha256 -and $locks['generated'].content.generatedFileCount -eq 179 -and $locks['generated'].content.generatorOutputCount -eq 4) 'Generated-input lineage drift.'
Assert ($locks['assembly'].content.solutionLockSha256 -ceq $locks['solution'].sha256 -and $locks['type'].content.solutionLockSha256 -ceq $locks['solution'].sha256 -and $locks['type'].content.assemblyLockSha256 -ceq $locks['assembly'].sha256) 'Compiled evidence lineage drift.'
$oldC1=Join-Path ([IO.Path]::GetTempPath()) 'ifx-c1-r3-e5dec30036424e0e89d1f5278b3b70c9/bundle/package/profiles/catalog/ifx_c1_r3_fixture/profile.json'
$oldC5=Join-Path ([IO.Path]::GetTempPath()) 'ifx-c5f-2ed76a91a7c9432fa35f0d59dd5a5f78/bundle/package/profiles/catalog/ifx_c5f_fixture/profile.json'
$r3=Get-Content (Join-Path $repo 'artifacts/guards/p10-ifx-c1-r3/test-runs/e5dec30036424e0e89d1f5278b3b70c9/summary.json') -Raw|ConvertFrom-Json -Depth 100
$c5=Get-Content (Join-Path $repo 'artifacts/guards/p10-ifx-c5f/test-runs/2ed76a91a7c9432fa35f0d59dd5a5f78/summary.json') -Raw|ConvertFrom-Json -Depth 100
Assert ((Hash $oldC1) -ceq $r3.evidence.profileSha256 -and (Hash $oldC5) -ceq $c5.profileSha256) 'Pinned fixture Profile config drift.'
$c1Profile=Get-Content $oldC1 -Raw|ConvertFrom-Json -AsHashtable -Depth 100
$c5Profile=Get-Content $oldC5 -Raw|ConvertFrom-Json -AsHashtable -Depth 100
$selections=@($c1Profile.moduleSelections)+@($c5Profile.moduleSelections)
Assert ($selections.Count -eq 37 -and @($selections.id|Sort-Object -Unique).Count -eq 37) 'Combined module selection collision.'
$lockSelections=@{'ifx-c1-type-provenance'='type';'ifx-c1-evaluated-reference'='graph';'ifx-solution-evidence'='solution';'ifx-assembly-evidence'='assembly';'ifx-frontend-evidence'='frontend';'ifx-database-evidence'='database'}
foreach($selection in $selections){
    if($lockSelections.ContainsKey($selection.id)){
        $key=$lockSelections[$selection.id];$selection.config.evidenceLockPath=$locks[$key].path;$selection.config.evidenceLockSha256=$locks[$key].sha256
    }
    if($selection.id -ceq 'ifx-database-evidence'){
        $db=$locks['database'].content
        $selection.config.authorityHashes=@(foreach($name in @('migrationCatalog','releaseManifest','safetyPolicy')){[ordered]@{id=$name;sha256=[string]$db.authorityHashes.$name}})
    }
}
$runId=[guid]::NewGuid().ToString('N');$runRoot=Join-Path ([IO.Path]::GetTempPath()) "ifx-c6b1-$runId"
$bundle=Join-Path $runRoot 'bundle';$package=Join-Path $bundle 'package';[void][IO.Directory]::CreateDirectory((Join-Path $package 'modules'))
$external=[Collections.Generic.List[object]]::new();$ceilingRows=[Collections.Generic.List[object]]::new()
foreach($entry in $inventory.modules){
    $id=[string]$entry.id;if($id -ceq 'architecture-conformance'){continue}
    $source=Join-Path $repo $entry.sourcePath;$manifestPath=Join-Path $source 'module.json'
    Assert ((Hash $manifestPath) -ceq $entry.manifestSha256 -and (Hash (Join-Path $source 'adapter.ps1')) -ceq $entry.adapterSha256 -and (Hash (Join-Path $source 'dependencies.lock.json')) -ceq $entry.dependencyLockSha256) "Module byte drift: $id"
    $manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json -Depth 100
    Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $basePackage 'core/contracts/module.schema.json') -ErrorAction Stop) "Module schema drift: $id"
    $selection=@($selections|Where-Object id -CEQ $id);Assert ($selection.Count -eq 1) "Missing Profile selection: $id"
    Assert (Test-Json -Json ($selection[0].config|ConvertTo-Json -Depth 100 -Compress) -SchemaFile (Join-Path $source 'config.schema.json') -ErrorAction Stop) "Config schema drift: $id"
    $dest=Join-Path $package "modules/$id";Copy-Item -LiteralPath $source -Destination $dest -Recurse
    $cap=$manifest.capabilities
    $ceiling=[ordered]@{readRoots=@($cap.readRoots);writeRoots=@($cap.writeRoots);processes=@($cap.processes);network=[bool]$cap.network;maxTimeoutSeconds=[int]$cap.timeoutSeconds}
    Assert ($ceiling.writeRoots.Count -eq 0 -and -not $ceiling.network) "Unsafe capability: $id"
    $external.Add([ordered]@{id=$id;version=$manifest.version;manifestPath="modules/$id/module.json";manifestSha256=Hash (Join-Path $dest 'module.json');allowedCapabilities=$ceiling})
    $ceilingRows.Add([ordered]@{moduleId=$id;allowedCapabilities=$ceiling})
}
Assert ($external.Count -eq 36) 'External manifest module count drift.'
$profilePath=Join-Path $package 'profiles/catalog/ifx_profile/profile.json'
$profile=[ordered]@{formatVersion=1;id='ifx_profile';version='0.3.0';projectIdentity=[ordered]@{id='ifx';relativeRoots=@('src','tests','tools','deployment','docs','mcp','artifacts')};moduleSelections=$selections;stageConfiguration=[ordered]@{bootstrap=[ordered]@{enabled=$false;modules=@()};analysis=[ordered]@{enabled=$false;modules=@()};pre=[ordered]@{enabled=$true;modules=@($c1Profile.stageConfiguration.pre.modules)};post=[ordered]@{enabled=$true;modules=@($c1Profile.stageConfiguration.post.modules)+@($c5Profile.stageConfiguration.post.modules)}};rules=@(@($c1Profile.rules)+@($c5Profile.rules)|Sort-Object -Unique);baselineRefs=@()}
WriteJson $profilePath $profile
Assert (Test-Json -LiteralPath $profilePath -SchemaFile (Join-Path $basePackage 'core/contracts/profile.schema.json') -ErrorAction Stop) 'Combined Profile schema drift.'
Assert ($profile.moduleSelections.Count -eq 37 -and $profile.stageConfiguration.pre.modules.Count -eq 10 -and $profile.stageConfiguration.post.modules.Count -eq 27 -and @($profile.rules).Count -eq 80 -and @($profile.baselineRefs).Count -eq 0) 'Combined Profile cardinality drift.'
$authorityMap=Join-Path $package 'profiles/catalog/ifx_profile/authority-map.json';Copy-Item -LiteralPath $inventoryFull -Destination $authorityMap
$lineagePath=Join-Path $package 'profiles/catalog/ifx_profile/evidence-lineage.json'
WriteJson $lineagePath ([ordered]@{formatVersion=1;sourceCommit=$commit;ordinalInventorySha256=Hash $inventoryFull;c1mDecisionSha256=Hash (Join-Path $repo 'docs/guards/inventories/20260924-ifx-c1-applicability-decisions.json');locks=@($locks.Values|ForEach-Object{[ordered]@{id=$_.id;gate=$_.gate;path=$_.path;sha256=$_.sha256}});g04Status='PRE-READY';g04BlockerCount=7;p103Deferred=@('G05-Phase9-eight','v3-pre-diff','v3-cross-platform-ubuntu-latest','v3-cross-platform-windows-latest')})
$files=@(Get-ChildItem -LiteralPath $package -File -Recurse|Sort-Object FullName|ForEach-Object{[ordered]@{path=[IO.Path]::GetRelativePath($package,$_.FullName).Replace('\','/');sha256=Hash $_.FullName;size=$_.Length}})
$manifestPath=Join-Path $bundle 'bundle-manifest.json'
WriteJson $manifestPath ([ordered]@{formatVersion=1;id='ifx-profile-candidate';version='0.3.0';compatibleApi='1.x';baseVersion='1.1.3';profiles=@([ordered]@{id='ifx_profile';version='0.3.0';path='profiles/catalog/ifx_profile/profile.json';sha256=Hash $profilePath});modules=@($external.ToArray());files=$files})
$reviewPath=Join-Path $runRoot 'synthetic-review.json'
WriteJson $reviewPath ([ordered]@{formatVersion=1;id='20260924-ifx-c6b1-synthetic-fixture';scope='synthetic-test-only';decision='accepted';acceptedBy=[ordered]@{authorityType='test-fixture';authorityId='ifx-c6b1-synthetic-fixture';candidateHostVerdictAllowed=$false};bundleManifestSha256=Hash $manifestPath;baseArchiveSha256=Hash $archive;moduleCeilings=@($ceilingRows.ToArray())})
$state=Join-Path $runRoot 'compose-state';$composeEvidence=Join-Path $runRoot 'compose-evidence';[void][IO.Directory]::CreateDirectory($state);[void][IO.Directory]::CreateDirectory($composeEvidence)
$composed=Join-Path $runRoot 'composed';$compositionReceipt=Join-Path $runRoot 'composition.receipt.json'
$compose=@(& pwsh -NoProfile -File (Join-Path $basePackage 'core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archive -BundleRoot $bundle -ReviewRecordPath $reviewPath -OutputInstallRoot $composed -CompositionReceiptPath $compositionReceipt -TargetRoot $repo -StateRoot $state -EvidenceRoot $composeEvidence -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Synthetic composition failed: $($compose -join ' ')"
$verify=@(& pwsh -NoProfile -File (Join-Path $basePackage 'core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $compositionReceipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0 -and (($verify -join "`n")|ConvertFrom-Json).status -ceq 'pass') 'Synthetic composition receipt failed.'
$packageBefore=Fingerprint (Join-Path $composed 'package');$lockBefore=@($locks.Values|ForEach-Object{"$($_.path)|$(Hash $_.full)"}) -join "`n"
$targetTrackedBefore=@(& git -C $repo status --porcelain --untracked-files=no) -join "`n";Assert ($LASTEXITCODE -eq 0) 'TargetRoot tracked status unavailable.'
$cases=[Collections.Generic.List[object]]::new()
$hostEvidence=Join-Path $runRoot 'host-evidence';[void][IO.Directory]::CreateDirectory($hostEvidence)
$typeRoot=[IO.Path]::GetDirectoryName($locks['type'].full)
Copy-Item -LiteralPath (Join-Path $typeRoot 'assembly-manifest.json') -Destination (Join-Path $hostEvidence 'assembly-manifest.json')
Copy-Item -LiteralPath (Join-Path $typeRoot 'assemblies') -Destination (Join-Path $hostEvidence 'assemblies') -Recurse
if(-not $SkipHost){
    foreach($spec in @([ordered]@{id='direct-pre';stage='pre';count=10;claims=22;dependencies=$false},[ordered]@{id='direct-post';stage='post';count=27;claims=57;dependencies=$false},[ordered]@{id='dependency-post';stage='post';count=37;claims=79;dependencies=$true})){
        $hostState=Join-Path $runRoot "host-state-$($spec.id)";[void][IO.Directory]::CreateDirectory($hostState)
        $args=@((Join-Path $composed 'host/v4-guards.dll'),'stage','run','--stage',$spec.stage,'--package-root',(Join-Path $composed 'package'),'--target-root',$repo,'--state-root',$hostState,'--evidence-root',$hostEvidence,'--profile','ifx_profile')
        if($spec.dependencies){$args+='--with-dependencies'}
        $lines=@(& dotnet @args 2>&1);$raw=$lines -join "`n";try{$result=$raw|ConvertFrom-Json -Depth 100}catch{throw "Non-JSON Host $($spec.id): $raw"}
        Assert ($LASTEXITCODE -eq 0 -and $result.status -ceq 'pass' -and @($result.moduleResults).Count -eq $spec.count -and @($result.coverage).Count -eq $spec.claims -and @($result.findings).Count -eq 0) "Integrated Host failed $($spec.id): $raw"
        Assert (@($result.coverage|Where-Object{$_.matched -lt $_.minimum}).Count -eq 0) "Vacuous coverage $($spec.id)."
        $expectedStages=if($spec.dependencies){'bootstrap,analysis,pre,post'}else{$spec.stage}
        Assert ((@($result.executedStages) -join ',') -ceq $expectedStages) "Unexpected stage order $($spec.id)."
        $cases.Add([ordered]@{id=$spec.id;status='pass';moduleCount=$spec.count;claimCount=$spec.claims;stages=@($result.executedStages)})
    }
}
$negativeCases=[Collections.Generic.List[object]]::new()
function Variant([string]$Id,[string]$Kind){
    $negativeBundle=Join-Path $runRoot "negative-$Id-bundle";Copy-Item -LiteralPath $bundle -Destination $negativeBundle -Recurse
    $negativeManifestPath=Join-Path $negativeBundle 'bundle-manifest.json'
    if($Kind -ceq 'tampered-manifest'){
        $bad=Get-Content $negativeManifestPath -Raw|ConvertFrom-Json -AsHashtable -Depth 100
        $bad.profiles[0].sha256=('0'*64);WriteJson $negativeManifestPath $bad
    }else{
        $negativeProfilePath=Join-Path $negativeBundle 'package/profiles/catalog/ifx_profile/profile.json'
        $badProfile=Get-Content $negativeProfilePath -Raw|ConvertFrom-Json -AsHashtable -Depth 100
        if($Kind -ceq 'baseline'){$badProfile.baselineRefs=@('baselines/undeclared-c6b1.json')}
        elseif($Kind -ceq 'missing-lock'){
            $typeSelection=@($badProfile.moduleSelections|Where-Object id -CEQ 'ifx-c1-type-provenance')
            Assert ($typeSelection.Count -eq 1) 'Missing type selection in negative fixture.'
            $typeSelection[0].config.evidenceLockPath='artifacts/guards/p10-ifx-c1-r1b/type-runs/00000000000000000000000000000000/evidence-lock.json'
        }else{throw "Unknown negative variant: $Kind"}
        WriteJson $negativeProfilePath $badProfile
        $bad=Get-Content $negativeManifestPath -Raw|ConvertFrom-Json -AsHashtable -Depth 100
        $bad.profiles[0].sha256=Hash $negativeProfilePath
        $entry=@($bad.files|Where-Object path -CEQ 'profiles/catalog/ifx_profile/profile.json')
        Assert ($entry.Count -eq 1) 'Profile entry missing in negative manifest.'
        $entry[0].sha256=Hash $negativeProfilePath;$entry[0].size=(Get-Item $negativeProfilePath).Length
        WriteJson $negativeManifestPath $bad
    }
    $negativeReview=Join-Path $runRoot "negative-$Id-review.json"
    $reviewCopy=Get-Content $reviewPath -Raw|ConvertFrom-Json -AsHashtable -Depth 100
    $reviewCopy.id="20260924-ifx-c6b1-$Id-synthetic-fixture";$reviewCopy.bundleManifestSha256=Hash $negativeManifestPath
    WriteJson $negativeReview $reviewCopy
    $negativeInstall=Join-Path $runRoot "negative-$Id-composed";$negativeReceipt=Join-Path $runRoot "negative-$Id-receipt.json"
    $lines=@(& pwsh -NoProfile -File (Join-Path $basePackage 'core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archive -BundleRoot $negativeBundle -ReviewRecordPath $negativeReview -OutputInstallRoot $negativeInstall -CompositionReceiptPath $negativeReceipt -TargetRoot $repo -StateRoot $state -EvidenceRoot $composeEvidence -AllowSyntheticFixture 2>&1)
    $composeExit=$LASTEXITCODE
    if($Kind -cne 'missing-lock'){
        Assert ($composeExit -ne 0 -and -not (Test-Path $negativeInstall)) "Negative $Id composition unexpectedly passed."
        $negativeCases.Add([ordered]@{id=$Id;status='blocked';phase='composition'})
        return
    }
    Assert ($composeExit -eq 0) 'Missing-lock negative must reach Host after schema-valid composition.'
    $negativeState=Join-Path $runRoot "negative-$Id-state";[void][IO.Directory]::CreateDirectory($negativeState)
    $output=@(& dotnet (Join-Path $negativeInstall 'host/v4-guards.dll') stage run --stage post --package-root (Join-Path $negativeInstall 'package') --target-root $repo --state-root $negativeState --evidence-root $hostEvidence --profile ifx_profile 2>&1)
    $hostExit=$LASTEXITCODE
    try{$result=($output -join "`n")|ConvertFrom-Json -Depth 100}catch{throw "Non-JSON missing-lock Host result: $($output -join ' ')"}
    $lockFinding=@($result.findings|Where-Object{$_.detectorId -ceq 'ifx-c1-type-provenance' -and $_.subject -like '*00000000000000000000000000000000/evidence-lock.json*'})
    Assert ($hostExit -ne 0 -and $result.status -ceq 'error' -and $result.exitCategory -ceq 'prerequisite-missing' -and $lockFinding.Count -eq 1) "Missing lock did not block Host at type provenance: exit=$hostExit status=$($result.status) category=$($result.exitCategory) findings=$(@($result.findings).Count)."
    $negativeCases.Add([ordered]@{id=$Id;status='blocked';phase='host';category=$result.exitCategory;findings=@($result.findings)})
}
Variant 'manifest-tamper' 'tampered-manifest'
Variant 'baseline-injection' 'baseline'
Variant 'missing-lock' 'missing-lock'
$targetTrackedAfter=@(& git -C $repo status --porcelain --untracked-files=no) -join "`n";Assert ($LASTEXITCODE -eq 0) 'TargetRoot tracked status unavailable.'
Assert ((Fingerprint (Join-Path $composed 'package')) -ceq $packageBefore -and (@($locks.Values|ForEach-Object{"$($_.path)|$(Hash $_.full)"}) -join "`n") -ceq $lockBefore -and $targetTrackedAfter -ceq $targetTrackedBefore) 'Package, evidence-lock or tracked TargetRoot bytes changed.'
$report=Join-Path (Full $EvidenceRoot) $runId;[void][IO.Directory]::CreateDirectory($report)
Copy-Item -LiteralPath $bundle -Destination (Join-Path $report 'bundle') -Recurse
WriteJson (Join-Path $report 'summary.json') ([ordered]@{formatVersion=1;status=$(if($SkipHost){'partial'}else{'pass'});scope='c6b1-synthetic-draft';hostValidated=[bool](-not $SkipHost);baseVersion='1.1.3';bundleVersion='0.3.0';sourceCommit=$commit;moduleSelections=37;externalModules=36;distinctClaims=79;baselineRefs=@();cases=@($cases.ToArray());negativeCases=@($negativeCases.ToArray());bundleManifestSha256=Hash $manifestPath;profileSha256=Hash $profilePath;ordinalInventorySha256=Hash $inventoryFull;compositionReceiptSha256=Hash $compositionReceipt;locks=@($locks.Values|ForEach-Object{[ordered]@{id=$_.id;path=$_.path;sha256=$_.sha256}});limitations=@('Synthetic composition is not Xiaolong Feng approval.','C6c dual-platform and independent negative certification remain required.','G04 PRE-READY and P10.3 deferrals remain open.')})
Write-Output "IFX C6b1 draft bundle test passed: $report"
