[CmdletBinding()]
param(
    [string]$EvidenceRoot='artifacts/guards/p10-ifx-c3e/test-runs',
    [string]$BaseInstallRoot='D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.3',
    [string]$BaseReceiptPath='D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.3.install.json',
    [string]$BaseArchivePath='artifacts/guards/p10-ifx-c3b/base-archive/v4-guards-1.1.3.zip'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Write-Json([string]$Path,$Value){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,(($Value | ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))}
function Inventory([string]$Root){@((Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object {"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"})) -join "`n"}
$candidateRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot=[IO.Path]::GetFullPath((Join-Path $candidateRoot '../../../..'))
$profilePath=Join-Path $candidateRoot 'profile.json'
$profile=Get-Content $profilePath -Raw | ConvertFrom-Json -Depth 100
$lock=Get-Content (Join-Path $candidateRoot 'authority-lock.json') -Raw | ConvertFrom-Json -Depth 100
$fixtures=Get-Content (Join-Path $candidateRoot 'fixtures/cases.json') -Raw | ConvertFrom-Json -Depth 30
$basePackage=Join-Path $BaseInstallRoot 'package'
$archive=if([IO.Path]::IsPathFullyQualified($BaseArchivePath)){$BaseArchivePath}else{Join-Path $repoRoot $BaseArchivePath}
Assert ($lock.formatVersion -eq 1 -and $lock.scope -ceq 'candidate-test-only' -and $lock.publishedBaseVersion -ceq '1.1.3' -and $lock.v4.claimCount -eq 15 -and $lock.v4.activeCheckCount -eq 79 -and $lock.v4.deferredCheckCount -eq 3) 'C3e lock identity drift.'
Assert (Test-Json -LiteralPath $profilePath -SchemaFile (Join-Path $basePackage 'core/contracts/profile.schema.json') -ErrorAction Stop) 'Candidate Profile schema failed.'
Assert ((Hash $profilePath) -ceq $lock.profileSha256) 'Candidate Profile hash drift.'
$matrixPath=Join-Path $repoRoot 'docs/guards/inventories/20260924-ifx-c3-g04-claim-matrix.json'
Assert ((Hash $matrixPath) -ceq $lock.matrixSha256) 'G04 claim matrix drift.'
$matrix=Get-Content $matrixPath -Raw | ConvertFrom-Json -Depth 100
$destinations=@($matrix.claims | Group-Object destination)
foreach($pair in @(@('C3b',12),@('C3c',47),@('C3d',20),@('P10.3-deferred',3))){Assert (@($matrix.claims | Where-Object destination -eq $pair[0]).Count -eq $pair[1]) "G04 destination count drift: $($pair[0])."}
Assert (@($matrix.claims).Count -eq 82 -and @($matrix.claims.id | Sort-Object -Unique).Count -eq 82) 'G04 check inventory drift.'
foreach($detector in $lock.v3.detectors){Assert ((Hash (Join-Path $repoRoot $detector.path)) -ceq $detector.sha256) "V3 detector drift: $($detector.path)."}
$moduleIds=@($lock.modules | ForEach-Object id)
$claimIds=[Collections.Generic.List[string]]::new();$ruleIds=[Collections.Generic.List[string]]::new()
foreach($module in $lock.modules){
    $root=Join-Path $repoRoot $module.sourceDirectory
    Assert ((Hash (Join-Path $root 'module.json')) -ceq $module.manifestSha256 -and (Hash (Join-Path $root 'policy.json')) -ceq $module.policySha256) "Module lock drift: $($module.id)."
    $manifest=Get-Content (Join-Path $root 'module.json') -Raw | ConvertFrom-Json -Depth 50
    $plan=Get-Content (Join-Path $root 'rule-execution-plan.json') -Raw | ConvertFrom-Json -Depth 50
    Assert (Test-Json -LiteralPath (Join-Path $root 'module.json') -SchemaFile (Join-Path $basePackage 'core/contracts/module.schema.json') -ErrorAction Stop) "Module schema failed: $($module.id)."
    Assert ($manifest.id -ceq $module.id -and (@($manifest.stages) -join '|') -ceq 'post' -and (@($manifest.capabilities.readRoots) -join '|') -ceq 'PackageRoot|TargetRoot' -and @($manifest.capabilities.writeRoots).Count -eq 0 -and -not $manifest.capabilities.network) "Module capabilities drift: $($module.id)."
    Assert ((Hash (Join-Path $root 'adapter.ps1')) -ceq $manifest.adapter.sha256 -and (Hash (Join-Path $root 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) "Module executable drift: $($module.id)."
    foreach($authority in $manifest.authorities){Assert ((Hash (Join-Path $repoRoot "$(Split-Path -Parent $module.sourceDirectory)/../$($authority.path)")) -ceq $authority.sha256) "Module internal authority drift: $($module.id)/$($authority.id)."}
    foreach($authority in $module.targetAuthorities){Assert ((Hash (Join-Path $repoRoot $authority.path)) -ceq $authority.sha256) "Target authority drift: $($authority.path)."}
    Assert (@($plan.rules).Count -eq @($module.claimIds).Count -and $plan.moduleId -ceq $module.id) "Rule Plan drift: $($module.id)."
    Assert ((@($plan.rules.claimId) -join '|') -ceq (@($module.claimIds) -join '|') -and (@($plan.rules.ruleId) -join '|') -ceq (@($module.ruleIds) -join '|')) "Rule identity drift: $($module.id)."
    foreach($rule in $plan.rules){Assert ($rule.stage -ceq 'post' -and $rule.severity -ceq 'blocking' -and $rule.minimumMatches -eq 1 -and $null -eq $rule.baseline) "Rule weakened: $($rule.ruleId).";$claimIds.Add($rule.claimId);$ruleIds.Add($rule.ruleId)}
    $selection=@($profile.moduleSelections | Where-Object id -eq $module.id)
    Assert ($selection.Count -eq 1 -and $selection[0].versionRange -ceq '>=0.1.0 <1.0.0' -and $selection[0].config.policySha256 -ceq $module.policySha256) "Profile selection drift: $($module.id)."
    Assert (Test-Json -Json ($selection[0].config | ConvertTo-Json -Depth 30 -Compress) -SchemaFile (Join-Path $root 'config.schema.json') -ErrorAction Stop) "Profile config schema failed: $($module.id)."
    Assert ((@($selection[0].config.enabledClaims) -join '|') -ceq (@($module.claimIds) -join '|') -and @($selection[0].config.authorityHashes).Count -eq @($module.targetAuthorities).Count) "Profile claim/authority count drift: $($module.id)."
    for($i=0;$i -lt @($module.targetAuthorities).Count;$i++){Assert ($selection[0].config.authorityHashes[$i].id -ceq $module.targetAuthorities[$i].id -and $selection[0].config.authorityHashes[$i].sha256 -ceq $module.targetAuthorities[$i].sha256) "Profile target authority drift: $($module.id)/$i."}
}
function Assert-Profile($Value){
    Assert ($Value.id -ceq 'ifx_g04_c3e_candidate' -and $Value.projectIdentity.id -ceq 'ifx' -and (@($Value.projectIdentity.relativeRoots) -join '|') -ceq 'src|deployment|docs' -and @($Value.baselineRefs).Count -eq 0) 'Profile identity/roots/baselines drift.'
    Assert (@($Value.moduleSelections).Count -eq 3 -and (@($Value.moduleSelections.id) -join '|') -ceq ($moduleIds -join '|') -and (@($Value.stageConfiguration.post.modules) -join '|') -ceq ($moduleIds -join '|')) 'Profile modules drift.'
    Assert (-not $Value.stageConfiguration.bootstrap.enabled -and -not $Value.stageConfiguration.analysis.enabled -and -not $Value.stageConfiguration.pre.enabled -and $Value.stageConfiguration.post.enabled) 'Profile stages drift.'
    Assert (@($Value.rules).Count -eq 15 -and (@($Value.rules) -join '|') -ceq (@($ruleIds.ToArray()) -join '|')) 'Profile rules drift.'
    foreach($module in $lock.modules){$s=@($Value.moduleSelections | Where-Object id -eq $module.id);Assert ($s.Count -eq 1 -and (@($s[0].config.enabledClaims) -join '|') -ceq (@($module.claimIds) -join '|')) "Profile claim drift: $($module.id)."}
}
Assert-Profile $profile
Assert ($claimIds.Count -eq 15 -and @($claimIds.ToArray() | Sort-Object -Unique).Count -eq 15 -and @($ruleIds.ToArray() | Sort-Object -Unique).Count -eq 15) 'Combined claims/rules duplicate or incomplete.'
foreach($mutation in @($fixtures.profileRejectCases)){
    $clone=$profile | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
    switch($mutation){
        'missing-module'{$clone.moduleSelections=@($clone.moduleSelections | Select-Object -Skip 1)}
        'missing-claim'{$clone.moduleSelections[0].config.enabledClaims=@($clone.moduleSelections[0].config.enabledClaims | Select-Object -Skip 1)}
        'missing-rule'{$clone.rules=@($clone.rules | Select-Object -Skip 1)}
        'baseline-injection'{$clone.baselineRefs=@('unreviewed-waiver.json')}
        default{throw "Unknown profile mutation: $mutation"}
    }
    $rejected=$false;try{Assert-Profile $clone}catch{$rejected=$true};Assert $rejected "Profile mutation was accepted: $mutation."
}
$baseCheck=& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $basePackage 'core/runtime/Test-V4Package.ps1') -PackageRoot $basePackage | ConvertFrom-Json -Depth 100
$receipt=Get-Content $BaseReceiptPath -Raw | ConvertFrom-Json -Depth 100
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.status -ceq 'pass' -and $baseCheck.packageHash -ceq $lock.publishedPackageSha256 -and (Hash $archive) -ceq $lock.publishedArchiveSha256 -and $receipt.archiveSha256 -ceq $lock.publishedArchiveSha256) 'Published 1.1.3 identity drift.'
$outputRoot=if([IO.Path]::IsPathFullyQualified($EvidenceRoot)){$EvidenceRoot}else{Join-Path $repoRoot $EvidenceRoot}
$runId=[Guid]::NewGuid().ToString('N')
$runRoot=Join-Path ([IO.Path]::GetTempPath()) "ifx-g04-c3e-$runId";[void][IO.Directory]::CreateDirectory($runRoot)
$reportRoot=Join-Path $outputRoot $runId;[void][IO.Directory]::CreateDirectory($reportRoot)
function New-Target([string]$Id,[string]$Mutation){
    $target=Join-Path $runRoot "target-$Id";[void][IO.Directory]::CreateDirectory($target)
    foreach($module in $lock.modules){foreach($a in $module.targetAuthorities){$to=Join-Path $target $a.path;if(-not [IO.File]::Exists($to)){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($to));[IO.File]::WriteAllBytes($to,[IO.File]::ReadAllBytes((Join-Path $repoRoot $a.path)))}}}
    switch($Mutation){
        'stale-authority'{$p=Join-Path $target 'src/ApiHost/IFX.ApiHost/Program.cs';[IO.File]::AppendAllText($p,"`n// stale candidate authority`n")}
        'missing-authority'{[IO.File]::Delete((Join-Path $target 'deployment/g04/release-orchestration.json'))}
        'zero-blockers'{$p=Join-Path $target 'docs/architecture/review/evidence/gates/G04/G04-phase12-status.json';$value=Get-Content $p -Raw | ConvertFrom-Json -Depth 100;$value.blockers=@();Write-Json $p $value}
        default{throw "Unknown target mutation: $Mutation"}
    }
    return $target
}
function New-Composition([string]$Id,$ProfileOverride){
    $bundle=Join-Path $runRoot "bundle-$Id";$package=Join-Path $bundle 'package';[void][IO.Directory]::CreateDirectory((Join-Path $package 'modules'))
    $ceiling=[ordered]@{readRoots=@('PackageRoot','TargetRoot');writeRoots=@();processes=@('pwsh');network=$false;maxTimeoutSeconds=60}
    $modules=@(foreach($module in $lock.modules){$to=Join-Path $package "modules/$($module.id)";Copy-Item -LiteralPath (Join-Path $repoRoot $module.sourceDirectory) -Destination $to -Recurse;[ordered]@{id=$module.id;version='0.1.0';manifestPath="modules/$($module.id)/module.json";manifestSha256=Hash (Join-Path $to 'module.json');allowedCapabilities=$ceiling}})
    $p=Join-Path $package 'profiles/catalog/ifx_g04_c3e_candidate/profile.json';[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($p))
    if($null -eq $ProfileOverride){Copy-Item -LiteralPath $profilePath -Destination $p}else{Write-Json $p $ProfileOverride}
    $files=@(Get-ChildItem -LiteralPath $package -File -Recurse | Sort-Object FullName | ForEach-Object {[ordered]@{path=[IO.Path]::GetRelativePath($package,$_.FullName).Replace('\','/');sha256=Hash $_.FullName;size=$_.Length}})
    $manifest=Join-Path $bundle 'bundle-manifest.json';Write-Json $manifest ([ordered]@{formatVersion=1;id="ifx-c3e-$Id-synthetic-extension";version='0.1.0';compatibleApi='1.x';baseVersion='1.1.3';profiles=@([ordered]@{id='ifx_g04_c3e_candidate';version='0.1.0';path='profiles/catalog/ifx_g04_c3e_candidate/profile.json';sha256=Hash $p});modules=$modules;files=$files})
    $review=Join-Path $runRoot "review-$Id.json";Write-Json $review ([ordered]@{formatVersion=1;id="20260924-ifx-c3e-$Id-synthetic-fixture";scope='synthetic-test-only';decision='accepted';acceptedBy=[ordered]@{authorityType='test-fixture';authorityId="ifx-c3e-$Id-synthetic-fixture";candidateHostVerdictAllowed=$false};bundleManifestSha256=Hash $manifest;baseArchiveSha256=Hash $archive;moduleCeilings=@($lock.modules | ForEach-Object {[ordered]@{moduleId=$_.id;allowedCapabilities=$ceiling}})})
    $install=Join-Path $runRoot "composed-$Id";$compositionReceipt=Join-Path $runRoot "composition-$Id.receipt.json";$state=Join-Path $runRoot "compose-state-$Id";$evidence=Join-Path $runRoot "compose-evidence-$Id";[void][IO.Directory]::CreateDirectory($state);[void][IO.Directory]::CreateDirectory($evidence)
    $output=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $basePackage 'core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archive -BundleRoot $bundle -ReviewRecordPath $review -OutputInstallRoot $install -CompositionReceiptPath $compositionReceipt -TargetRoot $repoRoot -StateRoot $state -EvidenceRoot $evidence -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Synthetic composition failed ($Id): $($output -join "`n")"
    $verified=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $basePackage 'core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $install -ReceiptPath $compositionReceipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
    Assert ($LASTEXITCODE -eq 0 -and (($verified -join "`n") | ConvertFrom-Json).status -ceq 'pass') "Composition receipt failed ($Id): $($verified -join "`n")"
    return [pscustomobject]@{install=$install;package=Join-Path $install 'package';profileHash=Hash $p}
}
function Invoke-Host([string]$Id,$Installation,[string]$Target,[bool]$Dependencies){
    $state=Join-Path $runRoot "host-state-$Id";$evidence=Join-Path $runRoot "host-evidence-$Id";[void][IO.Directory]::CreateDirectory($state);[void][IO.Directory]::CreateDirectory($evidence)
    $targetBefore=if($Target -ceq $repoRoot){@($lock.modules | ForEach-Object {$_.targetAuthorities} | ForEach-Object {"$($_.path)|$(Hash (Join-Path $Target $_.path))"}) -join "`n"}else{Inventory $Target}
    $packageBefore=Inventory $Installation.package
    $argsList=@((Join-Path $Installation.install 'host/v4-guards.dll'),'stage','run','--stage','post','--package-root',$Installation.package,'--target-root',$Target,'--state-root',$state,'--evidence-root',$evidence,'--profile','ifx_g04_c3e_candidate')
    if($Dependencies){$argsList+='--with-dependencies'}
    $output=@(& dotnet @argsList 2>&1);$exit=$LASTEXITCODE;$raw=$output -join "`n"
    try{$result=$raw | ConvertFrom-Json -Depth 100}catch{throw "Host output is not JSON ($Id): $raw"}
    $targetAfter=if($Target -ceq $repoRoot){@($lock.modules | ForEach-Object {$_.targetAuthorities} | ForEach-Object {"$($_.path)|$(Hash (Join-Path $Target $_.path))"}) -join "`n"}else{Inventory $Target}
    Assert ($targetAfter -ceq $targetBefore -and (Inventory $Installation.package) -ceq $packageBefore) "TargetRoot or PackageRoot changed: $Id."
    return [pscustomobject]@{result=$result;exitCode=$exit;raw=$raw}
}
$clean=New-Composition 'clean' $null
Assert ($clean.profileHash -ceq $lock.profileSha256) 'Composed Profile hash drift.'
$results=[Collections.Generic.List[object]]::new()
foreach($case in $fixtures.hostCases){
    $target=if($case.target -ceq 'real'){$repoRoot}else{New-Target $case.id $case.mutation}
    $installation=$clean
    if($case.mutation -ceq 'zero-blockers'){$override=$profile | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100;$selection=@($override.moduleSelections | Where-Object id -eq 'ifx-g04-closeout')[0];$entry=@($selection.config.authorityHashes | Where-Object id -eq 'g04Status')[0];$entry.sha256=Hash (Join-Path $target 'docs/architecture/review/evidence/gates/G04/G04-phase12-status.json');$installation=New-Composition $case.id $override}
    $run=Invoke-Host $case.id $installation $target ($case.mode -ceq 'dependencies')
    Assert (($case.status -ceq 'pass' -and $run.result.status -ceq 'pass') -or ($case.status -ceq 'blocked' -and $run.result.status -in @('fail','error'))) "Host case mismatch $($case.id): $($run.raw)"
    if($case.status -ceq 'pass'){
        Assert ($run.exitCode -eq 0 -and $run.result.exitCategory -ceq 'success' -and @($run.result.moduleResults).Count -eq 3 -and @($run.result.moduleResults | Where-Object status -ne 'pass').Count -eq 0 -and @($run.result.coverage).Count -eq 15 -and @($run.result.coverage | Where-Object {$_.matched -lt 1 -or $_.minimum -ne 1}).Count -eq 0 -and @($run.result.findings).Count -eq 0) "Combined G04 coverage incomplete: $($case.id)."
        $stages=if($case.mode -ceq 'dependencies'){'bootstrap|analysis|pre|post'}else{'post'}
        Assert ((@($run.result.executedStages) -join '|') -ceq $stages) "Stage sequence drift: $($case.id)."
        foreach($m in $lock.modules){Assert ($run.result.authorityHashes."module.$($m.id)" -ceq $m.manifestSha256) "Host module authority drift: $($m.id)."}
        Assert (@($run.result.authorityHashes.PSObject.Properties.Name | Where-Object {$_ -like 'baseline.*'}).Count -eq 0) 'Unexpected baseline loaded.'
    }else{
        Assert ($run.exitCode -ne 0 -and $run.result.status -in @('fail','error')) "Negative Host case was not blocking: $($case.id)."
        if($case.mutation -ceq 'zero-blockers'){Assert (@($run.result.findings | Where-Object {$_.subject -like '*blocker*' -or $_.subject -like '*matched 0*'}).Count -gt 0) 'Zero-blocker negative lacked a relevant finding.'}
    }
    $results.Add([ordered]@{id=$case.id;status=$run.result.status;exitCategory=$run.result.exitCategory;modules=@($run.result.moduleResults).Count;claims=@($run.result.coverage).Count})
}
$v3Root=Join-Path $runRoot 'v3-phase12';[void][IO.Directory]::CreateDirectory($v3Root)
$v3Output=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $repoRoot 'docs/guards/V3_ifx/stages/post/gates/specialized/scripts/Invoke-G04Verification.ps1') -OutputDirectory $v3Root 2>&1)
Assert ($LASTEXITCODE -eq 0) "Fresh V3 G04 replay failed: $($v3Output -join "`n")"
$v3Summary=Get-Content (Join-Path $v3Root 'verification-summary.json') -Raw | ConvertFrom-Json -Depth 100
$guard=Get-Content (Join-Path $v3Root 'guard.json') -Raw | ConvertFrom-Json -Depth 100
$inbound=Get-Content (Join-Path $v3Root 'plan02-c1.json') -Raw | ConvertFrom-Json -Depth 100
$status=Get-Content (Join-Path $repoRoot 'docs/architecture/review/evidence/gates/G04/G04-phase12-status.json') -Raw | ConvertFrom-Json -Depth 100
Assert ($v3Summary.result -ceq 'passed' -and $guard.result -ceq 'passed' -and $guard.phase -eq 12 -and @($guard.checks.PSObject.Properties).Count -eq 70 -and @($guard.checks.PSObject.Properties | Where-Object Value -eq $false).Count -eq 0) 'Fresh V3 G04 Phase 12 diverged.'
Assert ($inbound.result -ceq 'passed' -and @($inbound.checks.PSObject.Properties).Count -eq 12 -and @($inbound.checks.PSObject.Properties | Where-Object Value -eq $false).Count -eq 0) 'Fresh V3 Plan02-C1 inbound diverged.'
Assert ($status.status -ceq $lock.v3.closeout -and -not $status.gateClosed -and -not $status.approvalGranted -and (@($status.blockers.id) -join '|') -ceq (@($lock.v3.blockers) -join '|')) 'G04 PRE-READY/blockers drift.'
$after=& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $basePackage 'core/runtime/Test-V4Package.ps1') -PackageRoot $basePackage | ConvertFrom-Json -Depth 100
Assert ($LASTEXITCODE -eq 0 -and $after.packageHash -ceq $baseCheck.packageHash) 'Published Package changed during combined run.'
Copy-Item -LiteralPath $v3Root -Destination (Join-Path $reportRoot 'v3-phase12') -Recurse
Write-Json (Join-Path $reportRoot 'summary.json') ([ordered]@{formatVersion=1;status='pass';scope='candidate-level-c3e';publishedBaseVersion='1.1.3';profileSha256=$lock.profileSha256;v3=[ordered]@{phase12Checks=70;inboundChecks=12;closeout=$status.status;blockers=@($status.blockers.id)};v4=[ordered]@{moduleCount=3;claimCount=15;activeMappedChecks=79;deferredChecks=3;cases=@($results.ToArray())};knownDivergences=@($lock.knownDivergences);notAuthorized=@($lock.notAuthorized)})
Write-Output "IFX C3e combined G04 passed $(@($fixtures.hostCases).Count) Host cases, four Profile rejection controls and fresh V3 Phase 12/inbound. Evidence: $reportRoot"
