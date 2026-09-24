[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SolutionLockPath,
    [Parameter(Mandatory)][string]$AssemblyLockPath,
    [Parameter(Mandatory)][string]$FrontendLockPath,
    [Parameter(Mandatory)][string]$DatabaseLockPath,
    [string]$EvidenceRoot='artifacts/guards/p10-ifx-c5f/test-runs',
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
Assert ((Hash $archive) -ceq '28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e') 'Published archive drift.'
Assert ((Get-Content $BaseReceiptPath -Raw|ConvertFrom-Json).archiveSha256 -ceq (Hash $archive)) 'Published receipt drift.'
$baseCheck=& pwsh -NoProfile -File (Join-Path $BaseInstallRoot 'package/core/runtime/Test-V4Package.ps1') -PackageRoot (Join-Path $BaseInstallRoot 'package')|ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.packageHash -ceq '9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494') 'Published Package drift.'
$c1Summary=Join-Path $repo 'artifacts/guards/p10-ifx-c1c2-113/revalidation/6a33719885ee4a9faa3222be62cd1f19/summary.json'
Assert ([IO.File]::Exists($c1Summary)) 'C1/C2 1.1.3 revalidation summary missing.'
$c1=Get-Content $c1Summary -Raw|ConvertFrom-Json -Depth 100
Assert ($c1.status -ceq 'pass') 'C1/C2 1.1.3 revalidation did not pass.'
$g04StatusPath=Join-Path $repo 'docs/architecture/review/evidence/gates/G04/G04-phase12-status.json';$g04=Get-Content $g04StatusPath -Raw|ConvertFrom-Json -Depth 100
Assert ($g04.status -ceq 'PRE-READY' -and @($g04.blockers).Count -eq 7 -and -not $g04.gateClosed -and -not $g04.approvalGranted) 'G04 PRE-READY/blocker status drift.'
$locks=@{}
foreach($pair in @(@('ifx-solution-evidence',$SolutionLockPath),@('ifx-assembly-evidence',$AssemblyLockPath),@('ifx-frontend-evidence',$FrontendLockPath),@('ifx-database-evidence',$DatabaseLockPath))){
    $full=if([IO.Path]::IsPathFullyQualified($pair[1])){$pair[1]}else{Join-Path $repo $pair[1]}
    Assert ([IO.File]::Exists($full)) "Missing lock: $($pair[0])"
    $locks[$pair[0]]=[ordered]@{path=[IO.Path]::GetRelativePath($repo,$full).Replace('\','/');sha256=Hash $full;full=$full}
}
$moduleMap=[ordered]@{
    'ifx-g03-governance-core'='c2b1';'ifx-g03-catalog-semantics'='c2b2';'ifx-g03-source-reconciliation'='c2c1';'ifx-g03-snapshots'='c2c2';'ifx-g03-docs-closeout'='c2d'
    'ifx-g04-manifests'='c3b';'ifx-g04-runtime'='c3c';'ifx-g04-closeout'='c3d'
    'ifx-plan04-extraction'='c4a1';'ifx-plan04-tenant'='c4a2';'ifx-plan04-projection'='c4a3';'ifx-plan04-abstractions'='c4a4';'ifx-database-evidence'='c4b'
    'ifx-g05-inventory'='c4p0';'ifx-g05-protocol'='c4p1';'ifx-g05-execution-http'='c4p2';'ifx-g05-carriers'='c4p4p5';'ifx-g05-governance'='c4p6p7';'ifx-g05-closeout'='c4p8p11';'ifx-plan05-security'='c4s'
    'ifx-solution-evidence'='c5b';'ifx-assembly-evidence'='c5c';'ifx-frontend-evidence'='c5d';'ifx-history-integrity'='c5h'
}
Assert ($moduleMap.Count -eq 24) 'Reviewed Post module count drift.'
$c2Profile=Get-Content (Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c2e/profile.json') -Raw|ConvertFrom-Json -Depth 100
$c3Profile=Get-Content (Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c3e/profile.json') -Raw|ConvertFrom-Json -Depth 100
function C4-Selection([string]$Tranche,[string]$Id){
    $root=Join-Path $repo "artifacts/guards/p10-ifx-$Tranche/test-runs"
    foreach($run in @(Get-ChildItem -LiteralPath $root -Directory|Sort-Object LastWriteTimeUtc -Descending)){
        $summary=Join-Path $run.FullName 'summary.json';if(-not [IO.File]::Exists($summary)){continue}
        try{$result=Get-Content $summary -Raw|ConvertFrom-Json}catch{continue}
        if($result.status -cne 'pass'){continue}
        $profiles=@(Get-ChildItem -LiteralPath (Join-Path $run.FullName 'bundle/package/profiles/catalog') -File -Filter profile.json -Recurse -ErrorAction SilentlyContinue)
        foreach($path in $profiles){$profile=Get-Content $path.FullName -Raw|ConvertFrom-Json -Depth 100;$selection=@($profile.moduleSelections|Where-Object id -CEQ $Id);if($selection.Count -eq 1){return [ordered]@{selection=$selection[0];path=$path.FullName;sha256=Hash $path.FullName;summary=$summary}}}
    }
    throw "Passing C4 fixture Profile missing: $Tranche/$Id"
}
$runId=[guid]::NewGuid().ToString('N');$runRoot=Join-Path ([IO.Path]::GetTempPath()) "ifx-c5f-$runId";[void][IO.Directory]::CreateDirectory($runRoot)
$evidence=if([IO.Path]::IsPathFullyQualified($EvidenceRoot)){$EvidenceRoot}else{Join-Path $repo $EvidenceRoot};$reportRoot=Join-Path $evidence $runId;[void][IO.Directory]::CreateDirectory($reportRoot)
$bundle=Join-Path $runRoot 'bundle';$package=Join-Path $bundle 'package';[void][IO.Directory]::CreateDirectory((Join-Path $package 'modules'))
$selections=[Collections.Generic.List[object]]::new();$rules=[Collections.Generic.List[string]]::new();$claims=[Collections.Generic.List[string]]::new();$modules=[Collections.Generic.List[object]]::new();$sources=[Collections.Generic.List[object]]::new()
foreach($id in $moduleMap.Keys){
    $tranche=$moduleMap[$id];$source=Join-Path $repo "docs/guards/candidates/ifx-gate-coverage-$tranche/modules/$id";$destination=Join-Path $package "modules/$id"
    Copy-Item -LiteralPath $source -Destination $destination -Recurse
    $manifest=Get-Content (Join-Path $source 'module.json') -Raw|ConvertFrom-Json -Depth 100
    Assert (Test-Json -LiteralPath (Join-Path $source 'module.json') -SchemaFile (Join-Path $BaseInstallRoot 'package/core/contracts/module.schema.json') -ErrorAction Stop) "Module schema failed: $id"
    Assert ($manifest.id -ceq $id -and (@($manifest.stages)-join '|') -ceq 'post' -and (@($manifest.capabilities.readRoots)-join '|') -ceq 'PackageRoot|TargetRoot' -and @($manifest.capabilities.writeRoots).Count -eq 0 -and (@($manifest.capabilities.processes)-join '|') -ceq 'pwsh' -and $manifest.capabilities.network -eq $false) "Module capability drift: $id"
    Assert ((Hash (Join-Path $source 'adapter.ps1')) -ceq $manifest.adapter.sha256 -and (Hash (Join-Path $source 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) "Module byte lock drift: $id"
    foreach($authority in $manifest.authorities){Assert ((Hash (Join-Path $repo "docs/guards/candidates/ifx-gate-coverage-$tranche/$($authority.path)")) -ceq $authority.sha256) "Module authority drift: $id/$($authority.id)"}
    $plan=Get-Content (Join-Path $source 'rule-execution-plan.json') -Raw|ConvertFrom-Json -Depth 100
    foreach($rule in $plan.rules){Assert ($rule.stage -ceq 'post' -and $rule.severity -ceq 'blocking' -and $null -eq $rule.baseline -and $rule.minimumMatches -ge 1) "Rule weakened: $id/$($rule.ruleId)";$rules.Add([string]$rule.ruleId);$claims.Add([string]$rule.claimId)}
    $configSource='';$config=$null
    if($tranche -match '^c2'){$selection=@($c2Profile.moduleSelections|Where-Object id -CEQ $id);Assert ($selection.Count -eq 1) "C2 selection missing: $id";$config=$selection[0].config;$configSource='docs/guards/candidates/ifx-gate-coverage-c2e/profile.json'}
    elseif($tranche -match '^c3'){$selection=@($c3Profile.moduleSelections|Where-Object id -CEQ $id);Assert ($selection.Count -eq 1) "C3 selection missing: $id";$config=$selection[0].config;$configSource='docs/guards/candidates/ifx-gate-coverage-c3e/profile.json'}
    elseif($tranche -match '^c4'){$fixture=C4-Selection $tranche $id;$config=$fixture.selection.config;$configSource=[IO.Path]::GetRelativePath($repo,$fixture.path).Replace('\','/')}
    else{$config=[ordered]@{enabledClaims=@($plan.rules.claimId);policySha256=Hash (Join-Path $source 'policy.json')};$configSource='generated-from-current-c5-policy-and-lock'}
    if($locks.ContainsKey($id)){
        $config=($config|ConvertTo-Json -Depth 100|ConvertFrom-Json -AsHashtable -Depth 100)
        $config.evidenceLockPath=$locks[$id].path;$config.evidenceLockSha256=$locks[$id].sha256
    }
    if($id -ceq 'ifx-database-evidence'){
        $database=Get-Content $locks[$id].full -Raw|ConvertFrom-Json -AsHashtable -Depth 100
        $config.authorityHashes=@(foreach($authority in @('migrationCatalog','releaseManifest','safetyPolicy')){[ordered]@{id=$authority;sha256=[string]$database.authorityHashes[$authority]}})
    }
    Assert (Test-Json -Json ($config|ConvertTo-Json -Depth 100 -Compress) -SchemaFile (Join-Path $source 'config.schema.json') -ErrorAction Stop) "Config schema failed: $id"
    Assert ((@($config.enabledClaims)-join '|') -ceq (@($plan.rules.claimId)-join '|')) "Claim config drift: $id"
    $selections.Add([ordered]@{id=$id;versionRange='>=0.1.0 <1.0.0';config=$config})
    $ceiling=[ordered]@{readRoots=@('PackageRoot','TargetRoot');writeRoots=@();processes=@('pwsh');network=$false;maxTimeoutSeconds=[int]$manifest.capabilities.timeoutSeconds}
    $modules.Add([ordered]@{id=$id;version='0.1.0';manifestPath="modules/$id/module.json";manifestSha256=Hash (Join-Path $destination 'module.json');allowedCapabilities=$ceiling})
    $sources.Add([ordered]@{id=$id;tranche=$tranche;configSource=$configSource;configSha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(($config|ConvertTo-Json -Depth 100 -Compress)))).ToLowerInvariant()})
}
Assert (@($rules|Sort-Object -Unique).Count -eq $rules.Count -and @($claims|Sort-Object -Unique).Count -eq $claims.Count) 'Combined Post rule/claim collision.'
$profileId='ifx_c5f_fixture';$profilePath=Join-Path $package "profiles/catalog/$profileId/profile.json"
$profile=[ordered]@{formatVersion=1;id=$profileId;version='0.1.0';projectIdentity=[ordered]@{id='ifx';relativeRoots=@('src','tests','tools','deployment','docs','mcp','artifacts')};moduleSelections=@($selections.ToArray());stageConfiguration=[ordered]@{bootstrap=[ordered]@{enabled=$false;modules=@()};analysis=[ordered]@{enabled=$false;modules=@()};pre=[ordered]@{enabled=$false;modules=@()};post=[ordered]@{enabled=$true;modules=@($moduleMap.Keys)}};rules=@($rules.ToArray());baselineRefs=@()}
Write-Json $profilePath $profile
Assert (Test-Json -LiteralPath $profilePath -SchemaFile (Join-Path $BaseInstallRoot 'package/core/contracts/profile.schema.json') -ErrorAction Stop) 'Combined Profile schema failed.'
$bundleFiles=@(Get-ChildItem -LiteralPath $package -File -Recurse|Sort-Object FullName|ForEach-Object{[ordered]@{path=[IO.Path]::GetRelativePath($package,$_.FullName).Replace('\','/');sha256=Hash $_.FullName;size=$_.Length}})
$bundleManifest=Join-Path $bundle 'bundle-manifest.json'
Write-Json $bundleManifest ([ordered]@{formatVersion=1;id='ifx-c5f-synthetic-extension';version='0.1.0';compatibleApi='1.x';baseVersion='1.1.3';profiles=@([ordered]@{id=$profileId;version='0.1.0';path="profiles/catalog/$profileId/profile.json";sha256=Hash $profilePath});modules=@($modules.ToArray());files=$bundleFiles})
$review=Join-Path $runRoot 'synthetic-review.json'
Write-Json $review ([ordered]@{formatVersion=1;id='20260924-ifx-c5f-synthetic-fixture';scope='synthetic-test-only';decision='accepted';acceptedBy=[ordered]@{authorityType='test-fixture';authorityId='ifx-c5f-synthetic-fixture';candidateHostVerdictAllowed=$false};bundleManifestSha256=Hash $bundleManifest;baseArchiveSha256=Hash $archive;moduleCeilings=@($modules|ForEach-Object{[ordered]@{moduleId=$_.id;allowedCapabilities=$_.allowedCapabilities}})})
$composed=Join-Path $runRoot 'composed';$receipt=Join-Path $runRoot 'composition.receipt.json';$state=Join-Path $runRoot 'compose-state';$composeEvidence=Join-Path $runRoot 'compose-evidence';[void][IO.Directory]::CreateDirectory($state);[void][IO.Directory]::CreateDirectory($composeEvidence)
$compose=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archive -BundleRoot $bundle -ReviewRecordPath $review -OutputInstallRoot $composed -CompositionReceiptPath $receipt -TargetRoot $repo -StateRoot $state -EvidenceRoot $composeEvidence -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Synthetic composition failed: $($compose -join "`n")"
$verify=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $receipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0 -and (($verify -join "`n")|ConvertFrom-Json).status -ceq 'pass') 'Composed receipt check failed.'
$packageBefore=Inventory (Join-Path $composed 'package');$targetBefore=@($locks.Values|ForEach-Object{"$($_.path)|$(Hash $_.full)"}) -join "`n"
$cases=[Collections.Generic.List[object]]::new()
foreach($mode in @('direct','dependencies')){
    $hostState=Join-Path $runRoot "host-state-$mode";$hostEvidence=Join-Path $runRoot "host-evidence-$mode";[void][IO.Directory]::CreateDirectory($hostState);[void][IO.Directory]::CreateDirectory($hostEvidence)
    $arguments=@((Join-Path $composed 'host/v4-guards.dll'),'stage','run','--stage','post','--package-root',(Join-Path $composed 'package'),'--target-root',$repo,'--state-root',$hostState,'--evidence-root',$hostEvidence,'--profile',$profileId)
    if($mode -eq 'dependencies'){$arguments+='--with-dependencies'}
    $lines=@(& dotnet @arguments 2>&1);$exit=$LASTEXITCODE;$raw=$lines -join "`n"
    try{$result=$raw|ConvertFrom-Json -Depth 100}catch{throw "Non-JSON Host output ($mode): $raw"}
    $stages=if($mode -eq 'dependencies'){'bootstrap|analysis|pre|post'}else{'post'}
    Assert ((@($result.executedStages)-join '|') -ceq $stages) "Stage order drift: $mode"
    Assert ($exit -eq 0 -and $result.status -ceq 'pass' -and @($result.moduleResults).Count -eq 24 -and @($result.coverage).Count -eq $claims.Count -and @($result.coverage|Where-Object{$_.matched -lt $_.minimum}).Count -eq 0) "Full Post $mode failed: $raw"
    Assert (@($result.authorityHashes.PSObject.Properties.Name|Where-Object{$_ -like 'baseline.*'}).Count -eq 0) 'Unexpected baseline loaded.'
    $cases.Add([ordered]@{id=$mode;status=$result.status;modules=@($result.moduleResults).Count;claims=@($result.coverage).Count;matched=(@($result.coverage.matched|Measure-Object -Sum).Sum);stages=@($result.executedStages)})
}
$targetAfter=@($locks.Values|ForEach-Object{"$($_.path)|$(Hash $_.full)"}) -join "`n"
Assert ($targetBefore -ceq $targetAfter -and (Inventory (Join-Path $composed 'package')) -ceq $packageBefore) 'Host changed protected input bytes.'
$missing=($profile|ConvertTo-Json -Depth 100|ConvertFrom-Json -AsHashtable -Depth 100)
$solutionSelection=@($missing.moduleSelections|Where-Object id -CEQ 'ifx-solution-evidence')
Assert ($solutionSelection.Count -eq 1) 'Solution evidence selection missing.'
$solutionSelection[0].config.evidenceLockPath='artifacts/guards/p10-ifx-c5b/solution-runs/'+('0'*32)+'/evidence-lock.json'
$missingProfile=Join-Path $runRoot 'missing-evidence-profile.json';Write-Json $missingProfile $missing
$baseline=($profile|ConvertTo-Json -Depth 100|ConvertFrom-Json -AsHashtable -Depth 100)
$baseline.baselineRefs=@('baselines/undeclared-c5f.json')
$baselineProfile=Join-Path $runRoot 'baseline-injection-profile.json';Write-Json $baselineProfile $baseline
function Test-NegativeProfile([string]$Id,[string]$Variant,[bool]$RequireComposition){
    $negativeBundle=Join-Path $runRoot "bundle-$Id";Copy-Item -LiteralPath $bundle -Destination $negativeBundle -Recurse
    $negativePackage=Join-Path $negativeBundle 'package';$negativeProfilePath=Join-Path $negativePackage "profiles/catalog/$profileId/profile.json";Copy-Item -LiteralPath $Variant -Destination $negativeProfilePath -Force
    $negativeManifestPath=Join-Path $negativeBundle 'bundle-manifest.json';$negativeManifest=Get-Content $negativeManifestPath -Raw|ConvertFrom-Json -AsHashtable -Depth 100
    $negativeManifest.profiles[0].sha256=Hash $negativeProfilePath
    $profileEntry=@($negativeManifest.files|Where-Object path -CEQ "profiles/catalog/$profileId/profile.json")[0]
    $profileEntry.sha256=Hash $negativeProfilePath;$profileEntry.size=(Get-Item $negativeProfilePath).Length
    Write-Json $negativeManifestPath $negativeManifest
    $negativeReviewPath=Join-Path $runRoot "review-$Id.json";$negativeReview=Get-Content $review -Raw|ConvertFrom-Json -AsHashtable -Depth 100
    $negativeReview.id="20260924-ifx-c5f-$Id-synthetic-fixture";$negativeReview.bundleManifestSha256=Hash $negativeManifestPath
    Write-Json $negativeReviewPath $negativeReview
    $install=Join-Path $runRoot "composed-$Id";$negativeReceipt=Join-Path $runRoot "receipt-$Id.json"
    $negativeState=Join-Path $runRoot "compose-state-$Id";$negativeEvidence=Join-Path $runRoot "compose-evidence-$Id"
    [void][IO.Directory]::CreateDirectory($negativeState);[void][IO.Directory]::CreateDirectory($negativeEvidence)
    $output=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archive -BundleRoot $negativeBundle -ReviewRecordPath $negativeReviewPath -OutputInstallRoot $install -CompositionReceiptPath $negativeReceipt -TargetRoot $repo -StateRoot $negativeState -EvidenceRoot $negativeEvidence -AllowSyntheticFixture 2>&1)
    if($LASTEXITCODE -ne 0){Assert (-not $RequireComposition) "$Id unexpectedly failed composition: $($output -join "`n")";return [ordered]@{id=$Id;status='blocked-at-composition'}}
    $hostState=Join-Path $runRoot "host-state-$Id";$hostEvidence=Join-Path $runRoot "host-evidence-$Id"
    [void][IO.Directory]::CreateDirectory($hostState);[void][IO.Directory]::CreateDirectory($hostEvidence)
    $lines=@(& dotnet (Join-Path $install 'host/v4-guards.dll') stage run --stage post --package-root (Join-Path $install 'package') --target-root $repo --state-root $hostState --evidence-root $hostEvidence --profile $profileId 2>&1)
    $exit=$LASTEXITCODE;$result=($lines -join "`n")|ConvertFrom-Json -Depth 100
    Assert ($exit -ne 0 -and $result.status -in @('fail','error')) "$Id did not block."
    return [ordered]@{id=$Id;status=$result.status;exitCategory=$result.exitCategory}
}
$cases.Add((Test-NegativeProfile 'missing-evidence' $missingProfile $true))
$cases.Add((Test-NegativeProfile 'baseline-injection' $baselineProfile $false))
Assert ((Inventory (Join-Path $composed 'package')) -ceq $packageBefore) 'Negative tests changed accepted Package bytes.'
Write-Json (Join-Path $reportRoot 'summary.json') ([ordered]@{formatVersion=1;status='pass';scope='candidate-c5f-full-post';baseVersion='1.1.3';moduleCount=24;claimCount=$claims.Count;ruleCount=$rules.Count;baselineRefs=@();cases=@($cases);configSources=@($sources.ToArray());c1RevalidationSha256=Hash $c1Summary;g04StatusSha256=Hash $g04StatusPath;g04Blockers=@($g04.blockers.id);p103Deferred=@('v3-pre-diff','v3-cross-platform-ubuntu-latest','v3-cross-platform-windows-latest','G05-Phase9-eight');profileSha256=Hash $profilePath;packageHash=$baseCheck.packageHash})
Write-Output "IFX C5f full reviewed Post direct/dependency integration passed. Evidence: $reportRoot"
