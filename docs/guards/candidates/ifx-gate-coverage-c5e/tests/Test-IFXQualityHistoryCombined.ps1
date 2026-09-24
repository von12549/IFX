[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SolutionLockPath,
    [Parameter(Mandatory)][string]$AssemblyLockPath,
    [Parameter(Mandatory)][string]$FrontendLockPath,
    [Parameter(Mandatory)][string]$DatabaseLockPath,
    [string]$EvidenceRoot='artifacts/guards/p10-ifx-c5e/test-runs',
    [string]$BaseInstallRoot='D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.3',
    [string]$BaseReceiptPath='D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.3.install.json',
    [string]$BaseArchivePath='artifacts/guards/p10-ifx-c3b/base-archive/v4-guards-1.1.3.zip'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Write-Json([string]$Path,$Value){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))}
function Inventory([string]$Root){@(Get-ChildItem -LiteralPath $Root -File -Recurse -Force|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"}) -join "`n"}
$candidate=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$repo=[IO.Path]::GetFullPath((Join-Path $candidate '../../../..'))
$archive=if([IO.Path]::IsPathFullyQualified($BaseArchivePath)){$BaseArchivePath}else{Join-Path $repo $BaseArchivePath}
Assert ((Hash $archive) -ceq '28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e') 'Published 1.1.3 archive drift.'
Assert ((Get-Content $BaseReceiptPath -Raw|ConvertFrom-Json).archiveSha256 -ceq (Hash $archive)) 'Published receipt drift.'
$baseCheck=& pwsh -NoProfile -File (Join-Path $BaseInstallRoot 'package/core/runtime/Test-V4Package.ps1') -PackageRoot (Join-Path $BaseInstallRoot 'package')|ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.packageHash -ceq '9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494') 'Published Package drift.'
$locks=@{}
foreach($pair in @(@('solution',$SolutionLockPath),@('assembly',$AssemblyLockPath),@('frontend',$FrontendLockPath),@('database',$DatabaseLockPath))){
    $path=if([IO.Path]::IsPathFullyQualified($pair[1])){$pair[1]}else{Join-Path $repo $pair[1]}
    Assert ([IO.File]::Exists($path)) "Missing $($pair[0]) lock."
    $locks[$pair[0]]=[ordered]@{path=[IO.Path]::GetRelativePath($repo,$path).Replace('\','/');sha256=Hash $path;full=$path}
}
$dbLock=Get-Content $locks.database.full -Raw|ConvertFrom-Json -AsHashtable -Depth 100
Assert ($dbLock.gate -ceq 'Database' -and $dbLock.result -ceq 'passed') 'Database lock was not refreshed.'
$dbAuthorities=@(foreach($id in @('migrationCatalog','releaseManifest','safetyPolicy')){[ordered]@{id=$id;sha256=[string]$dbLock.authorityHashes[$id]}})
$items=@(
    [ordered]@{id='ifx-solution-evidence';tranche='c5b';lock='solution';claim='IFX.C5.SOLUTION_QUALITY';minimum=4},
    [ordered]@{id='ifx-assembly-evidence';tranche='c5c';lock='assembly';claim='IFX.C5.ASSEMBLY_QUALITY';minimum=7},
    [ordered]@{id='ifx-frontend-evidence';tranche='c5d';lock='frontend';claim='IFX.C5.FRONTEND_QUALITY';minimum=5},
    [ordered]@{id='ifx-history-integrity';tranche='c5h';lock='';claim='IFX.C5.HISTORY_INTEGRITY';minimum=18},
    [ordered]@{id='ifx-database-evidence';tranche='c4b';lock='database';claim='IFX.C4.DATABASE_EVIDENCE';minimum=1}
)
$runId=[guid]::NewGuid().ToString('N');$runRoot=Join-Path ([IO.Path]::GetTempPath()) "ifx-c5e-$runId";[void][IO.Directory]::CreateDirectory($runRoot)
$evidence=if([IO.Path]::IsPathFullyQualified($EvidenceRoot)){$EvidenceRoot}else{Join-Path $repo $EvidenceRoot};$reportRoot=Join-Path $evidence $runId;[void][IO.Directory]::CreateDirectory($reportRoot)
$bundle=Join-Path $runRoot 'bundle';$package=Join-Path $bundle 'package';[void][IO.Directory]::CreateDirectory((Join-Path $package 'modules'))
$selections=[Collections.Generic.List[object]]::new();$rules=[Collections.Generic.List[string]]::new();$modules=[Collections.Generic.List[object]]::new();$moduleHashes=[ordered]@{}
foreach($item in $items){
    $source=Join-Path $repo "docs/guards/candidates/ifx-gate-coverage-$($item.tranche)/modules/$($item.id)"
    $destination=Join-Path $package "modules/$($item.id)";Copy-Item -LiteralPath $source -Destination $destination -Recurse
    $manifestPath=Join-Path $source 'module.json';$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json -Depth 50
    Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $BaseInstallRoot 'package/core/contracts/module.schema.json') -ErrorAction Stop) "Module schema failed: $($item.id)"
    Assert ($manifest.id -ceq $item.id -and (@($manifest.capabilities.readRoots)-join '|') -ceq 'PackageRoot|TargetRoot' -and @($manifest.capabilities.writeRoots).Count -eq 0 -and (@($manifest.capabilities.processes)-join '|') -ceq 'pwsh' -and $manifest.capabilities.network -eq $false) "Module capability drift: $($item.id)"
    Assert ((Hash (Join-Path $source 'adapter.ps1')) -ceq $manifest.adapter.sha256 -and (Hash (Join-Path $source 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) "Executable byte drift: $($item.id)"
    foreach($authority in $manifest.authorities){Assert ((Hash (Join-Path $repo "docs/guards/candidates/ifx-gate-coverage-$($item.tranche)/$($authority.path)")) -ceq $authority.sha256) "Module authority drift: $($item.id)/$($authority.id)"}
    $rulePlan=Get-Content (Join-Path $source 'rule-execution-plan.json') -Raw|ConvertFrom-Json -Depth 50
    Assert ($rulePlan.rules.Count -eq 1 -and $rulePlan.rules[0].claimId -ceq $item.claim -and $rulePlan.rules[0].minimumMatches -eq $item.minimum -and $rulePlan.rules[0].severity -ceq 'blocking' -and $null -eq $rulePlan.rules[0].baseline) "Rule claim drift: $($item.id)"
    $rules.Add([string]$rulePlan.rules[0].ruleId)
    $config=[ordered]@{enabledClaims=@($item.claim);policySha256=Hash (Join-Path $source 'policy.json')}
    if($item.lock){$config.evidenceLockPath=$locks[$item.lock].path;$config.evidenceLockSha256=$locks[$item.lock].sha256}
    if($item.id -ceq 'ifx-database-evidence'){$config.authorityHashes=$dbAuthorities}
    Assert (Test-Json -Json ($config|ConvertTo-Json -Depth 50 -Compress) -SchemaFile (Join-Path $source 'config.schema.json') -ErrorAction Stop) "Module config schema failed: $($item.id)"
    $selections.Add([ordered]@{id=$item.id;versionRange='>=0.1.0 <1.0.0';config=$config})
    $ceiling=[ordered]@{readRoots=@('PackageRoot','TargetRoot');writeRoots=@();processes=@('pwsh');network=$false;maxTimeoutSeconds=[int]$manifest.capabilities.timeoutSeconds}
    $modules.Add([ordered]@{id=$item.id;version='0.1.0';manifestPath="modules/$($item.id)/module.json";manifestSha256=Hash (Join-Path $destination 'module.json');allowedCapabilities=$ceiling})
    $moduleHashes[$item.id]=Hash (Join-Path $destination 'module.json')
}
Assert (@($rules|Sort-Object -Unique).Count -eq 5 -and @($selections).Count -eq 5) 'Combined rule identity collision.'
$profileId='ifx_c5e_fixture';$profilePath=Join-Path $package "profiles/catalog/$profileId/profile.json"
$profile=[ordered]@{formatVersion=1;id=$profileId;version='0.1.0';projectIdentity=[ordered]@{id='ifx';relativeRoots=@('src','tests','tools','deployment','docs','mcp','artifacts')};moduleSelections=@($selections.ToArray());stageConfiguration=[ordered]@{bootstrap=[ordered]@{enabled=$false;modules=@()};analysis=[ordered]@{enabled=$false;modules=@()};pre=[ordered]@{enabled=$false;modules=@()};post=[ordered]@{enabled=$true;modules=@($items.id)}};rules=@($rules.ToArray());baselineRefs=@()}
Write-Json $profilePath $profile
Assert (Test-Json -LiteralPath $profilePath -SchemaFile (Join-Path $BaseInstallRoot 'package/core/contracts/profile.schema.json') -ErrorAction Stop) 'Combined Profile schema failed.'
$bundleFiles=@(Get-ChildItem -LiteralPath $package -File -Recurse|Sort-Object FullName|ForEach-Object{[ordered]@{path=[IO.Path]::GetRelativePath($package,$_.FullName).Replace('\','/');sha256=Hash $_.FullName;size=$_.Length}})
$bundleManifest=Join-Path $bundle 'bundle-manifest.json'
Write-Json $bundleManifest ([ordered]@{formatVersion=1;id='ifx-c5e-synthetic-extension';version='0.1.0';compatibleApi='1.x';baseVersion='1.1.3';profiles=@([ordered]@{id=$profileId;version='0.1.0';path="profiles/catalog/$profileId/profile.json";sha256=Hash $profilePath});modules=@($modules.ToArray());files=$bundleFiles})
$review=Join-Path $runRoot 'synthetic-review.json'
Write-Json $review ([ordered]@{formatVersion=1;id='20260924-ifx-c5e-synthetic-fixture';scope='synthetic-test-only';decision='accepted';acceptedBy=[ordered]@{authorityType='test-fixture';authorityId='ifx-c5e-synthetic-fixture';candidateHostVerdictAllowed=$false};bundleManifestSha256=Hash $bundleManifest;baseArchiveSha256=Hash $archive;moduleCeilings=@($modules|ForEach-Object{[ordered]@{moduleId=$_.id;allowedCapabilities=$_.allowedCapabilities}})})
$composed=Join-Path $runRoot 'composed';$receipt=Join-Path $runRoot 'composition.receipt.json';$state=Join-Path $runRoot 'compose-state';$composeEvidence=Join-Path $runRoot 'compose-evidence';[void][IO.Directory]::CreateDirectory($state);[void][IO.Directory]::CreateDirectory($composeEvidence)
$compose=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archive -BundleRoot $bundle -ReviewRecordPath $review -OutputInstallRoot $composed -CompositionReceiptPath $receipt -TargetRoot $repo -StateRoot $state -EvidenceRoot $composeEvidence -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Synthetic composition failed: $($compose -join "`n")"
$verify=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $receipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0 -and (($verify -join "`n")|ConvertFrom-Json).status -ceq 'pass') 'Composed receipt check failed.'
$packageBefore=Inventory (Join-Path $composed 'package')
$protected=@($locks.Values|ForEach-Object{"$($_.path)|$(Hash $_.full)"})+@('IFX.sln','src/Frontend/IFX.FrontEnd/package-lock.json','docs/guards/V3_ifx/stages/post/gates/historical-integrity/manifest.json'|ForEach-Object{"$_|$(Hash (Join-Path $repo $_))"})
$cases=[Collections.Generic.List[object]]::new()
foreach($mode in @('direct','dependencies')){
    $hostState=Join-Path $runRoot "host-state-$mode";$hostEvidence=Join-Path $runRoot "host-evidence-$mode";[void][IO.Directory]::CreateDirectory($hostState);[void][IO.Directory]::CreateDirectory($hostEvidence)
    $arguments=@((Join-Path $composed 'host/v4-guards.dll'),'stage','run','--stage','post','--package-root',(Join-Path $composed 'package'),'--target-root',$repo,'--state-root',$hostState,'--evidence-root',$hostEvidence,'--profile',$profileId)
    if($mode -eq 'dependencies'){$arguments+='--with-dependencies'}
    $lines=@(& dotnet @arguments 2>&1);$exit=$LASTEXITCODE;$result=($lines -join "`n")|ConvertFrom-Json -Depth 100
    Assert ($exit -eq 0 -and $result.status -ceq 'pass' -and @($result.moduleResults).Count -eq 5 -and @($result.coverage).Count -eq 5 -and @($result.coverage|Where-Object{$_.matched -lt $_.minimum}).Count -eq 0 -and (@($result.coverage.matched|Measure-Object -Sum).Sum -eq 43)) "Combined Host $mode failed: $($lines -join "`n")"
    $stages=if($mode -eq 'dependencies'){'bootstrap|analysis|pre|post'}else{'post'}
    Assert ((@($result.executedStages)-join '|') -ceq $stages) "Stage dependency order drift: $mode"
    Assert (@($result.authorityHashes.PSObject.Properties.Name|Where-Object{$_ -like 'baseline.*'}).Count -eq 0) 'Unexpected baseline loaded.'
    foreach($item in $items){Assert ($result.authorityHashes."module.$($item.id)" -ceq $moduleHashes[$item.id]) "Module authority drift: $($item.id)"}
    $cases.Add([ordered]@{id=$mode;status=$result.status;stages=@($result.executedStages);matched=(@($result.coverage.matched|Measure-Object -Sum).Sum)})
}
$protectedAfter=@($locks.Values|ForEach-Object{"$($_.path)|$(Hash $_.full)"})+@('IFX.sln','src/Frontend/IFX.FrontEnd/package-lock.json','docs/guards/V3_ifx/stages/post/gates/historical-integrity/manifest.json'|ForEach-Object{"$_|$(Hash (Join-Path $repo $_))"})
Assert (($protected -join "`n") -ceq ($protectedAfter -join "`n") -and (Inventory (Join-Path $composed 'package')) -ceq $packageBefore) 'Host changed protected TargetRoot or PackageRoot bytes.'
$negative=@($profile|ConvertTo-Json -Depth 100|ConvertFrom-Json -Depth 100)
$negative[0].moduleSelections[0].config.evidenceLockPath='artifacts/guards/p10-ifx-c5b/solution-runs/'+('0'*32)+'/evidence-lock.json'
$negativeProfile=Join-Path $runRoot 'missing-evidence-profile.json';Write-Json $negativeProfile $negative[0]
$fakeBaseline=@($profile|ConvertTo-Json -Depth 100|ConvertFrom-Json -Depth 100);$fakeBaseline[0].baselineRefs=@('baselines/undeclared-c5e.json')
$baselineProfile=Join-Path $runRoot 'baseline-injection-profile.json';Write-Json $baselineProfile $fakeBaseline[0]
function Test-NegativeProfile([string]$Id,[string]$Variant,[bool]$RequireComposition){
    $negativeBundle=Join-Path $runRoot "bundle-$Id";Copy-Item -LiteralPath $bundle -Destination $negativeBundle -Recurse
    $negativePackage=Join-Path $negativeBundle 'package';$negativeProfilePath=Join-Path $negativePackage "profiles/catalog/$profileId/profile.json";Copy-Item -LiteralPath $Variant -Destination $negativeProfilePath -Force
    $negativeManifestPath=Join-Path $negativeBundle 'bundle-manifest.json';$negativeManifest=Get-Content $negativeManifestPath -Raw|ConvertFrom-Json -AsHashtable -Depth 100
    $negativeManifest.profiles[0].sha256=Hash $negativeProfilePath
    $profileEntry=@($negativeManifest.files|Where-Object path -CEQ "profiles/catalog/$profileId/profile.json")[0];$profileEntry.sha256=Hash $negativeProfilePath;$profileEntry.size=(Get-Item $negativeProfilePath).Length
    Write-Json $negativeManifestPath $negativeManifest
    $negativeReviewPath=Join-Path $runRoot "review-$Id.json";$negativeReview=Get-Content $review -Raw|ConvertFrom-Json -AsHashtable -Depth 100;$negativeReview.id="20260924-ifx-c5e-$Id-synthetic-fixture";$negativeReview.bundleManifestSha256=Hash $negativeManifestPath;Write-Json $negativeReviewPath $negativeReview
    $install=Join-Path $runRoot "composed-$Id";$negativeReceipt=Join-Path $runRoot "receipt-$Id.json";$negativeState=Join-Path $runRoot "compose-state-$Id";$negativeEvidence=Join-Path $runRoot "compose-evidence-$Id";[void][IO.Directory]::CreateDirectory($negativeState);[void][IO.Directory]::CreateDirectory($negativeEvidence)
    $output=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archive -BundleRoot $negativeBundle -ReviewRecordPath $negativeReviewPath -OutputInstallRoot $install -CompositionReceiptPath $negativeReceipt -TargetRoot $repo -StateRoot $negativeState -EvidenceRoot $negativeEvidence -AllowSyntheticFixture 2>&1)
    if($LASTEXITCODE -ne 0){Assert (-not $RequireComposition) "$Id unexpectedly failed composition: $($output -join "`n")";return [ordered]@{id=$Id;status='blocked-at-composition'}}
    $hostState=Join-Path $runRoot "host-state-$Id";$hostEvidence=Join-Path $runRoot "host-evidence-$Id";[void][IO.Directory]::CreateDirectory($hostState);[void][IO.Directory]::CreateDirectory($hostEvidence)
    $lines=@(& dotnet (Join-Path $install 'host/v4-guards.dll') stage run --stage post --package-root (Join-Path $install 'package') --target-root $repo --state-root $hostState --evidence-root $hostEvidence --profile $profileId 2>&1)
    $exit=$LASTEXITCODE;$result=($lines -join "`n")|ConvertFrom-Json -Depth 100
    Assert ($exit -ne 0 -and $result.status -in @('fail','error')) "$Id did not block."
    return [ordered]@{id=$Id;status=$result.status;exitCategory=$result.exitCategory}
}
$cases.Add((Test-NegativeProfile 'missing-evidence' $negativeProfile $true))
$cases.Add((Test-NegativeProfile 'baseline-injection' $baselineProfile $false))
Write-Json (Join-Path $reportRoot 'summary.json') ([ordered]@{formatVersion=1;status='pass';scope='candidate-c5e-five-module';baseVersion='1.1.3';moduleCount=5;claimCount=5;matchedChecks=43;baselineRefs=@();cases=@($cases);locks=@($locks.GetEnumerator()|ForEach-Object{[ordered]@{id=$_.Key;path=$_.Value.path;sha256=$_.Value.sha256}});profileSha256=Hash $profilePath;packageHash=$baseCheck.packageHash;notes=@('C1-C4 wider integration remains C5f','Constituent zero-match controls remain independently verified')})
Write-Output "IFX C5e five-module direct/dependency Host Post passed. Evidence: $reportRoot"
