[CmdletBinding()]
param([string]$BaseInstallRoot='D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.3',[string]$BaseReceiptPath='D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.3.install.json',[string]$BaseArchivePath='artifacts/guards/p10-ifx-c3b/base-archive/v4-guards-1.1.3.zip',[string]$EvidenceRoot='artifacts/guards/p10-ifx-c1-r2b/test-runs')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert([bool]$Ok,[string]$Why){if(-not $Ok){throw $Why}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Json([string]$Path,$Value){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))}
function Inventory([string]$Root){@(Get-ChildItem -LiteralPath $Root -File -Recurse -Force|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"}) -join "`n"}
$candidate=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$repo=[IO.Path]::GetFullPath((Join-Path $candidate '../../../..'))
$archive=if([IO.Path]::IsPathFullyQualified($BaseArchivePath)){$BaseArchivePath}else{Join-Path $repo $BaseArchivePath}
Assert ((Hash $archive) -ceq '28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e') 'Published archive drift.'
Assert ((Get-Content $BaseReceiptPath -Raw|ConvertFrom-Json).archiveSha256 -ceq (Hash $archive)) 'Published receipt drift.'
$basePackage=Join-Path $BaseInstallRoot 'package'
$baseCheck=& pwsh -NoProfile -File (Join-Path $basePackage 'core/runtime/Test-V4Package.ps1') -PackageRoot $basePackage|ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.packageHash -ceq '9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494') 'Published Package drift.'
$source=Join-Path $candidate 'modules/ifx-c1-evaluated-reference';$module=Get-Content (Join-Path $source 'module.json') -Raw|ConvertFrom-Json -Depth 100
Assert (Test-Json -LiteralPath (Join-Path $source 'module.json') -SchemaFile (Join-Path $basePackage 'core/contracts/module.schema.json') -ErrorAction Stop) 'Module schema failed.'
Assert ((Hash (Join-Path $source 'adapter.ps1')) -ceq $module.adapter.sha256 -and (Hash (Join-Path $source 'dependencies.lock.json')) -ceq $module.dependencyLock.sha256) 'Module hash drift.'
foreach($authority in $module.authorities){Assert ((Hash (Join-Path $candidate $authority.path)) -ceq $authority.sha256) "Authority drift: $($authority.id)"}
$runId=[guid]::NewGuid().ToString('N')
$lines=@(& pwsh -NoProfile -File (Join-Path $candidate 'Invoke-IFXEvaluatedGraphProducer.ps1') -TargetRoot $repo -RunId $runId 2>&1)
Assert ($LASTEXITCODE -eq 0) "Controlled producer failed: $($lines -join ' ')"
$lockPath=Join-Path $repo "artifacts/guards/p10-ifx-c1-r2b/evaluation-runs/$runId/evidence-lock.json"
$lock=Get-Content $lockPath -Raw|ConvertFrom-Json -Depth 100
Assert (@($lock.projects).Count -eq 58 -and @($lock.edges).Count -eq 155 -and $lock.rawReferenceCount -eq 155 -and $lock.rawEvaluatedDelta -eq 0) 'Real evaluated graph baseline drift.'
$evidence=if([IO.Path]::IsPathFullyQualified($EvidenceRoot)){$EvidenceRoot}else{Join-Path $repo $EvidenceRoot};$report=Join-Path $evidence $runId
$runRoot=Join-Path ([IO.Path]::GetTempPath()) "ifx-c1-r2b-$runId";[void][IO.Directory]::CreateDirectory($runRoot)
$bundle=Join-Path $runRoot 'bundle';$package=Join-Path $bundle 'package';[void][IO.Directory]::CreateDirectory((Join-Path $package 'modules'))
Copy-Item -LiteralPath $source -Destination (Join-Path $package 'modules/ifx-c1-evaluated-reference') -Recurse
$config=[ordered]@{enabledClaims=@('IFX.C1.EVALUATED_REFERENCE_GRAPH');policySha256=Hash (Join-Path $source 'policy.json');evidenceLockPath="artifacts/guards/p10-ifx-c1-r2b/evaluation-runs/$runId/evidence-lock.json";evidenceLockSha256=Hash $lockPath}
Assert (Test-Json -Json ($config|ConvertTo-Json -Depth 10 -Compress) -SchemaFile (Join-Path $source 'config.schema.json') -ErrorAction Stop) 'Config schema failed.'
$profileId='ifx_c1_r2b_fixture';$profilePath=Join-Path $package "profiles/catalog/$profileId/profile.json"
$profile=[ordered]@{formatVersion=1;id=$profileId;version='0.1.0';projectIdentity=[ordered]@{id='ifx';relativeRoots=@('src','tests','tools','deployment','docs','mcp','artifacts')};moduleSelections=@([ordered]@{id='ifx-c1-evaluated-reference';versionRange='>=0.1.0 <1.0.0';config=$config});stageConfiguration=[ordered]@{bootstrap=[ordered]@{enabled=$false;modules=@()};analysis=[ordered]@{enabled=$false;modules=@()};pre=[ordered]@{enabled=$false;modules=@()};post=[ordered]@{enabled=$true;modules=@('ifx-c1-evaluated-reference')}};rules=@('C1-EVALUATED-RING-REFERENCE','C1-EVALUATED-OWNERSHIP');baselineRefs=@()}
Json $profilePath $profile
Assert (Test-Json -LiteralPath $profilePath -SchemaFile (Join-Path $basePackage 'core/contracts/profile.schema.json') -ErrorAction Stop) 'Profile schema failed.'
$files=@(Get-ChildItem -LiteralPath $package -File -Recurse|Sort-Object FullName|ForEach-Object{[ordered]@{path=[IO.Path]::GetRelativePath($package,$_.FullName).Replace('\','/');sha256=Hash $_.FullName;size=$_.Length}})
$manifest=Join-Path $bundle 'bundle-manifest.json';$ceiling=[ordered]@{readRoots=@('PackageRoot','TargetRoot');writeRoots=@();processes=@('pwsh','git');network=$false;maxTimeoutSeconds=180}
Json $manifest ([ordered]@{formatVersion=1;id='ifx-c1-r2b-synthetic-extension';version='0.1.0';compatibleApi='1.x';baseVersion='1.1.3';profiles=@([ordered]@{id=$profileId;version='0.1.0';path="profiles/catalog/$profileId/profile.json";sha256=Hash $profilePath});modules=@([ordered]@{id='ifx-c1-evaluated-reference';version='0.1.0';manifestPath='modules/ifx-c1-evaluated-reference/module.json';manifestSha256=Hash (Join-Path $package 'modules/ifx-c1-evaluated-reference/module.json');allowedCapabilities=$ceiling});files=$files})
$review=Join-Path $runRoot 'synthetic-review.json'
Json $review ([ordered]@{formatVersion=1;id='20260924-ifx-c1-r2b-synthetic-fixture';scope='synthetic-test-only';decision='accepted';acceptedBy=[ordered]@{authorityType='test-fixture';authorityId='ifx-c1-r2b-synthetic-fixture';candidateHostVerdictAllowed=$false};bundleManifestSha256=Hash $manifest;baseArchiveSha256=Hash $archive;moduleCeilings=@([ordered]@{moduleId='ifx-c1-evaluated-reference';allowedCapabilities=$ceiling})})
$composed=Join-Path $runRoot 'composed';$receipt=Join-Path $runRoot 'composition.receipt.json';$state=Join-Path $runRoot 'compose-state';$composeEvidence=Join-Path $runRoot 'compose-evidence'
[void][IO.Directory]::CreateDirectory($state);[void][IO.Directory]::CreateDirectory($composeEvidence)
$output=@(& pwsh -NoProfile -File (Join-Path $basePackage 'core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archive -BundleRoot $bundle -ReviewRecordPath $review -OutputInstallRoot $composed -CompositionReceiptPath $receipt -TargetRoot $repo -StateRoot $state -EvidenceRoot $composeEvidence -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Synthetic composition failed: $($output -join ' ')"
$verify=@(& pwsh -NoProfile -File (Join-Path $basePackage 'core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $receipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0 -and (($verify -join "`n")|ConvertFrom-Json).status -ceq 'pass') 'Composition receipt failed.'
$packageBefore=Inventory (Join-Path $composed 'package');$lockBefore=Hash $lockPath
$cases=[Collections.Generic.List[object]]::new()
foreach($mode in @('direct','dependencies')){
    $hostState=Join-Path $runRoot "host-state-$mode";[void][IO.Directory]::CreateDirectory($hostState)
    $args=@((Join-Path $composed 'host/v4-guards.dll'),'stage','run','--stage','post','--package-root',(Join-Path $composed 'package'),'--target-root',$repo,'--state-root',$hostState,'--evidence-root',$composeEvidence,'--profile',$profileId)
    if($mode -eq 'dependencies'){$args+='--with-dependencies'}
    $lines=@(& dotnet @args 2>&1);$raw=$lines -join "`n"
    try{$result=$raw|ConvertFrom-Json -Depth 100}catch{throw "Host output is not JSON ($mode): $raw"}
    Assert ($LASTEXITCODE -eq 0 -and $result.status -ceq 'pass' -and @($result.coverage|Where-Object claimId -CEQ 'IFX.C1.EVALUATED_REFERENCE_GRAPH').Count -eq 1) "Host failed ($mode): $raw"
    $coverage=@($result.coverage|Where-Object claimId -CEQ 'IFX.C1.EVALUATED_REFERENCE_GRAPH')[0]
    Assert ($coverage.matched -eq 147) "Host evaluated coverage drift ($mode): $raw"
    $cases.Add([ordered]@{id="host-$mode";status='pass';matched=$coverage.matched})
}
function Adapter($Cfg){
    $payload=[ordered]@{formatVersion=1;stage='post';targetRoot=$repo;packageRoot=(Join-Path $composed 'package');relativeRoots=@('src');config=$Cfg}
    $prior=$env:V4_STAGE_INPUT_JSON
    try{$env:V4_STAGE_INPUT_JSON=$payload|ConvertTo-Json -Depth 20 -Compress;$lines=@(& pwsh -NoProfile -File (Join-Path $composed 'package/modules/ifx-c1-evaluated-reference/adapter.ps1') 2>&1);$code=$LASTEXITCODE}finally{$env:V4_STAGE_INPUT_JSON=$prior}
    Assert ($code -eq 0) "Adapter process failed: $($lines -join ' ')"
    $raw=$lines -join "`n";Assert (Test-Json -Json $raw -SchemaFile (Join-Path $source 'result.schema.json') -ErrorAction Stop) 'Adapter result schema failed.'
    return $raw|ConvertFrom-Json -Depth 50
}
$missing=$config|ConvertTo-Json -Depth 10|ConvertFrom-Json -AsHashtable
$missing.evidenceLockPath='artifacts/guards/p10-ifx-c1-r2b/evaluation-runs/'+('0'*32)+'/evidence-lock.json'
$negative=Adapter $missing;Assert ($negative.status -ceq 'error' -and $negative.exitCategory -ceq 'prerequisite-missing') 'Missing lock did not block.'
$cases.Add([ordered]@{id='missing-lock';status='blocked'})
$original=[IO.File]::ReadAllBytes($lockPath)
try{
    $stale=Get-Content $lockPath -Raw|ConvertFrom-Json -AsHashtable -DateKind String
    $stale.createdAt=[DateTimeOffset]::UtcNow.AddHours(-2).ToString('o');$stale.expiresAt=[DateTimeOffset]::UtcNow.AddHours(-1).ToString('o')
    Json $lockPath $stale;$cfg=$config|ConvertTo-Json -Depth 10|ConvertFrom-Json -AsHashtable;$cfg.evidenceLockSha256=Hash $lockPath
    $negative=Adapter $cfg;Assert ($negative.status -ceq 'error' -and $negative.exitCategory -ceq 'integrity-failure') 'Stale lock did not block.'
    $cases.Add([ordered]@{id='stale-lock';status='blocked'})
    $empty=Get-Content $lockPath -Raw|ConvertFrom-Json -AsHashtable -DateKind String;$empty.createdAt=[DateTimeOffset]::UtcNow.ToString('o');$empty.expiresAt=[DateTimeOffset]::UtcNow.AddMinutes(30).ToString('o');$empty.edges=@();$empty.evaluatedReferenceCount=0
    Json $lockPath $empty;$cfg.evidenceLockSha256=Hash $lockPath
    $negative=Adapter $cfg;Assert ($negative.status -ceq 'error') 'Empty lock did not block.'
    $cases.Add([ordered]@{id='empty-lock';status='blocked'})
}finally{[IO.File]::WriteAllBytes($lockPath,$original)}
$synthetic=Get-Content $lockPath -Raw|ConvertFrom-Json -AsHashtable -DateKind String
$from='src/Modules/CRM/IFX.Modules.CRM.Domain/IFX.Modules.CRM.Domain.csproj';$to='src/Modules/CRM/IFX.Modules.CRM.Contracts/IFX.Modules.CRM.Contracts.csproj'
$synthetic.edges+=@{from=$from;to=$to;definer=$from;stopsFlow=$false};$synthetic.evaluatedReferenceCount++;$synthetic.rawEvaluatedDelta++
try{Json $lockPath $synthetic;$cfg=$config|ConvertTo-Json -Depth 10|ConvertFrom-Json -AsHashtable;$cfg.evidenceLockSha256=Hash $lockPath;$negative=Adapter $cfg;Assert ($negative.status -ceq 'fail' -and @($negative.findings|Where-Object ruleId -CEQ 'C1-EVALUATED-RING-REFERENCE').Count -gt 0) 'Forbidden evaluated edge did not block.';$cases.Add([ordered]@{id='forbidden-edge';status='blocked'})}finally{[IO.File]::WriteAllBytes($lockPath,$original)}
function Fixture([string]$Kind){
    $root=Join-Path $runRoot "fixture-$Kind";[void][IO.Directory]::CreateDirectory($root)
    $projectInputs=@(Get-ChildItem -LiteralPath (Join-Path $repo 'src') -Recurse -File|Where-Object{$_.Extension -in '.csproj','.props','.targets' -and $_.FullName -notmatch '[\\/](bin|obj)[\\/]'})
    foreach($input in $projectInputs){
        $relative=[IO.Path]::GetRelativePath($repo,$input.FullName);$dest=Join-Path $root $relative
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest));Copy-Item -LiteralPath $input.FullName -Destination $dest
    }
    foreach($relative in @('Directory.Build.props','Directory.Packages.props')+@($policy.sourcePolicies|ForEach-Object path)){
        $dest=Join-Path $root $relative;[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest));Copy-Item -LiteralPath (Join-Path $repo $relative) -Destination $dest
    }
    $domain=Join-Path $root 'src/Modules/CRM/IFX.Modules.CRM.Domain/IFX.Modules.CRM.Domain.csproj'
    $reference='<ItemGroup><ProjectReference Include="../IFX.Modules.CRM.Contracts/IFX.Modules.CRM.Contracts.csproj" /></ItemGroup>'
    if($Kind -ceq 'props'){
        $props=Join-Path $root 'Directory.Build.props';$text=[IO.File]::ReadAllText($props)
        $text=$text.Replace('</Project>',"<ItemGroup Condition=`"'`$(MSBuildProjectName)' == 'IFX.Modules.CRM.Domain'`"><ProjectReference Include=`"../IFX.Modules.CRM.Contracts/IFX.Modules.CRM.Contracts.csproj`" /></ItemGroup></Project>")
        [IO.File]::WriteAllText($props,$text,[Text.UTF8Encoding]::new($false))
    }else{
        $extra=Join-Path ([IO.Path]::GetDirectoryName($domain)) 'C1Injected.targets'
        [IO.File]::WriteAllText($extra,"<Project>$reference</Project>",[Text.UTF8Encoding]::new($false))
        $text=[IO.File]::ReadAllText($domain).Replace('</Project>','<Import Project="C1Injected.targets" /></Project>')
        [IO.File]::WriteAllText($domain,$text,[Text.UTF8Encoding]::new($false))
    }
    $gitOut=@(& git -C $root init -q 2>&1);Assert ($LASTEXITCODE -eq 0) "Fixture git init failed: $($gitOut -join ' ')"
    $gitOut=@(& git -C $root add . 2>&1);Assert ($LASTEXITCODE -eq 0) "Fixture git add failed: $($gitOut -join ' ')"
    $gitOut=@(& git -C $root -c user.name=IFXTest -c user.email=ifx-test@example.invalid commit -qm fixture 2>&1);Assert ($LASTEXITCODE -eq 0) "Fixture git commit failed: $($gitOut -join ' ')"
    $fixtureId=[guid]::NewGuid().ToString('N')
    $lines=@(& pwsh -NoProfile -File (Join-Path $candidate 'Invoke-IFXEvaluatedGraphProducer.ps1') -TargetRoot $root -RunId $fixtureId 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Fixture graph producer failed ($Kind): $($lines -join ' ')"
    $fixtureLock=Join-Path $root "artifacts/guards/p10-ifx-c1-r2b/evaluation-runs/$fixtureId/evidence-lock.json"
    $document=Get-Content $fixtureLock -Raw|ConvertFrom-Json -Depth 100
    Assert ($document.rawReferenceCount -eq 155 -and $document.evaluatedReferenceCount -eq 156 -and $document.rawEvaluatedDelta -eq 1) "Fixture graph delta incorrect ($Kind)."
    $fixtureCfg=[ordered]@{enabledClaims=@('IFX.C1.EVALUATED_REFERENCE_GRAPH');policySha256=Hash (Join-Path $source 'policy.json');evidenceLockPath="artifacts/guards/p10-ifx-c1-r2b/evaluation-runs/$fixtureId/evidence-lock.json";evidenceLockSha256=Hash $fixtureLock}
    $payload=[ordered]@{formatVersion=1;stage='post';targetRoot=$root;packageRoot=(Join-Path $composed 'package');relativeRoots=@('src');config=$fixtureCfg}
    $prior=$env:V4_STAGE_INPUT_JSON
    try{$env:V4_STAGE_INPUT_JSON=$payload|ConvertTo-Json -Depth 20 -Compress;$lines=@(& pwsh -NoProfile -File (Join-Path $composed 'package/modules/ifx-c1-evaluated-reference/adapter.ps1') 2>&1);$code=$LASTEXITCODE}finally{$env:V4_STAGE_INPUT_JSON=$prior}
    Assert ($code -eq 0) "Fixture adapter failed ($Kind): $($lines -join ' ')"
    $raw=$lines -join "`n";Assert (Test-Json -Json $raw -SchemaFile (Join-Path $source 'result.schema.json') -ErrorAction Stop) "Fixture result schema failed ($Kind)."
    $result=$raw|ConvertFrom-Json -Depth 100
    Assert ($result.status -ceq 'fail' -and @($result.findings|Where-Object ruleId -CEQ 'C1-EVALUATED-RING-REFERENCE').Count -gt 0) "Evaluated-only forbidden edge did not block ($Kind): $raw"
    $cases.Add([ordered]@{id="evaluated-only-$Kind";status='blocked';raw=155;evaluated=156})
}
$policy=Get-Content (Join-Path $source 'policy.json') -Raw|ConvertFrom-Json
Fixture 'props'
Fixture 'import'
function Commit-Fixture([string]$Root){
    $output=@(& git -C $Root add . 2>&1);Assert ($LASTEXITCODE -eq 0) "Fixture stage failed: $($output -join ' ')"
    $output=@(& git -C $Root -c user.name=IFXTest -c user.email=ifx-test@example.invalid commit -qm negative 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Fixture commit failed: $($output -join ' ')"
}
function Producer-Negative([string]$Id,[string]$Root){
    $newId=[guid]::NewGuid().ToString('N')
    $output=@(& pwsh -NoProfile -File (Join-Path $candidate 'Invoke-IFXEvaluatedGraphProducer.ps1') -TargetRoot $Root -RunId $newId 2>&1)
    Assert ($LASTEXITCODE -ne 0) "Unsafe graph producer case unexpectedly passed ($Id): $($output -join ' ')"
    $cases.Add([ordered]@{id=$Id;status='blocked'})
}
$negativeRoot=Join-Path $runRoot 'fixture-import'
$negativeProject=Join-Path $negativeRoot 'src/Modules/CRM/IFX.Modules.CRM.Domain/IFX.Modules.CRM.Domain.csproj'
$savedProject=[IO.File]::ReadAllText($negativeProject)
[IO.File]::WriteAllText($negativeProject,$savedProject.Replace('C1Injected.targets','Missing.targets'),[Text.UTF8Encoding]::new($false))
Commit-Fixture $negativeRoot;Producer-Negative 'missing-import' $negativeRoot
[IO.File]::WriteAllText($negativeProject,$savedProject.Replace('C1Injected.targets','../../../../../../outside.targets'),[Text.UTF8Encoding]::new($false))
Commit-Fixture $negativeRoot;Producer-Negative 'escaping-import' $negativeRoot
[IO.File]::WriteAllText($negativeProject,$savedProject,[Text.UTF8Encoding]::new($false))
$extra=Join-Path ([IO.Path]::GetDirectoryName($negativeProject)) 'C1Injected.targets'
[IO.File]::WriteAllText($extra,'<Project><ItemGroup><ProjectReference Include="../Missing/Missing.csproj" /></ItemGroup></Project>',[Text.UTF8Encoding]::new($false))
Commit-Fixture $negativeRoot;Producer-Negative 'unresolved-reference' $negativeRoot
$tampered=$config|ConvertTo-Json -Depth 10|ConvertFrom-Json -AsHashtable
$tampered.evidenceLockSha256='0'*64
$negative=Adapter $tampered;Assert ($negative.status -ceq 'error' -and $negative.exitCategory -ceq 'integrity-failure') 'Altered lock hash did not block.'
$cases.Add([ordered]@{id='altered-lock-hash';status='blocked'})
Assert ((Hash $lockPath) -ceq $lockBefore -and (Inventory (Join-Path $composed 'package')) -ceq $packageBefore) 'Host or negative controls mutated lock or PackageRoot.'
Json (Join-Path $report 'summary.json') ([ordered]@{formatVersion=1;status='pass';scope='r2b-evaluated-graph-only';baseVersion='1.1.3';projectCount=58;evaluatedReferenceCount=155;inScopeMatched=147;lockPath=$config.evidenceLockPath;lockSha256=$lockBefore;cases=@($cases.ToArray());notes=@('Isolated 58-project props/import fixtures each produce an evaluated-only forbidden edge and blocking Post result.','Generated C# and integrated C1 identity remain open.')})
Write-Output "IFX C1 R2b evaluated graph evidence passed: $report"
