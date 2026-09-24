[CmdletBinding()]
param([string]$BaseInstallRoot='D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.3',[string]$BaseReceiptPath='D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.3.install.json',[string]$BaseArchivePath='artifacts/guards/p10-ifx-c3b/base-archive/v4-guards-1.1.3.zip',[string]$EvidenceRoot='artifacts/guards/p10-ifx-c1-r3/test-runs')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert([bool]$Ok,[string]$Why){if(-not $Ok){throw $Why}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Json([string]$Path,$Value){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))}
function Inventory([string]$Root){@(Get-ChildItem -LiteralPath $Root -File -Recurse -Force|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"}) -join "`n"}
function LatestLock([string]$Pattern,[string]$Gate){
    $files=@(Get-ChildItem -Path (Join-Path $repo $Pattern) -File -ErrorAction SilentlyContinue|Sort-Object LastWriteTimeUtc -Descending)
    foreach($file in $files){try{$value=Get-Content $file.FullName -Raw|ConvertFrom-Json -Depth 100 -DateKind String}catch{continue};if($value.gate -ceq $Gate -and $value.result -ceq 'passed'){return $file.FullName}}
    throw "No passing $Gate lock at $Pattern"
}
function Fresh([string]$Path,[string]$Gate,[int]$Seconds){
    Assert ([IO.File]::Exists($Path)) "Missing $Gate lock."
    $lock=Get-Content $Path -Raw|ConvertFrom-Json -Depth 100 -DateKind String
    Assert ($lock.gate -ceq $Gate -and $lock.result -ceq 'passed') "$Gate lock invalid."
    $time=if($lock.PSObject.Properties.Name -contains 'createdAt'){[DateTimeOffset]::Parse([string]$lock.createdAt)}elseif($lock.PSObject.Properties.Name -contains 'completedAt'){[DateTimeOffset]::Parse([string]$lock.completedAt)}else{throw "Missing $Gate timestamp"}
    Assert ($time -le [DateTimeOffset]::UtcNow.AddMinutes(5) -and $time -ge [DateTimeOffset]::UtcNow.AddSeconds(-$Seconds)) "$Gate lock expired."
    if($lock.PSObject.Properties.Name -contains 'expiresAt'){Assert ([DateTimeOffset]::Parse([string]$lock.expiresAt) -gt [DateTimeOffset]::UtcNow) "$Gate lock expiry passed."}
    return $lock
}
function Run([string]$Program,[string[]]$Arguments,[string]$Label){
    $lines=@(& $Program @Arguments 2>&1)
    Assert ($LASTEXITCODE -eq 0) "$Label failed: $($lines -join ' ')"
    return $lines
}
$candidate=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$repo=[IO.Path]::GetFullPath((Join-Path $candidate '../../..'))
$archive=if([IO.Path]::IsPathFullyQualified($BaseArchivePath)){$BaseArchivePath}else{Join-Path $repo $BaseArchivePath}
Assert ((Hash $archive) -ceq '28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e') 'Published archive drift.'
Assert ((Get-Content $BaseReceiptPath -Raw|ConvertFrom-Json).archiveSha256 -ceq (Hash $archive)) 'Published receipt drift.'
$basePackage=Join-Path $BaseInstallRoot 'package'
$baseCheck=& pwsh -NoProfile -File (Join-Path $basePackage 'core/runtime/Test-V4Package.ps1') -PackageRoot $basePackage|ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.packageHash -ceq '9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494') 'Published Package drift.'
$c1c2Path=Join-Path $repo 'artifacts/guards/p10-ifx-c1c2-113/revalidation/6a33719885ee4a9faa3222be62cd1f19/summary.json'
$c5fPath=Join-Path $repo 'artifacts/guards/p10-ifx-c5f/test-runs/2ed76a91a7c9432fa35f0d59dd5a5f78/summary.json'
Assert ((Hash $c1c2Path) -ceq '9ad299755ce6a3556b227cda9905fba6d8055868984395befbd7b15571e863e2' -and (Hash $c5fPath) -ceq '6ad95f76cce837a9efc02fa941c2f8f60e470657a5698ee87415309acc3387cc') 'Prior C1/C2 or C5f summary drift.'
$priorC1C2=Get-Content $c1c2Path -Raw|ConvertFrom-Json -Depth 100;$priorC5f=Get-Content $c5fPath -Raw|ConvertFrom-Json -Depth 100
Assert ($priorC1C2.status -ceq 'pass' -and @($priorC1C2.suites).Count -eq 18 -and $priorC5f.status -ceq 'pass' -and $priorC5f.moduleCount -eq 24 -and $priorC5f.claimCount -eq 54) 'Prior evidence result drift.'
$r1bNegativePath=Join-Path $repo 'artifacts/guards/p10-ifx-c1-r1b/test-runs/6637eb1a6e3f45ccb12f3a1e03fa39fb/summary.json'
$r2bNegativePath=Join-Path $repo 'artifacts/guards/p10-ifx-c1-r2b/test-runs/5c87ad16738c4e4d9b9a4aa6ee01a263/summary.json'
Assert ((Hash $r1bNegativePath) -ceq 'a36bdf9de8f0d1dfbb73f2b5957f327a3eb34c7454c18a0dc743b75f8ab948e0' -and (Hash $r2bNegativePath) -ceq 'c04f3cc459e6047c362b8986f76296e139f5df10cc154e33d4600e4c6c2afc5a') 'R1/R2 negative evidence drift.'
$r1bNegative=Get-Content $r1bNegativePath -Raw|ConvertFrom-Json -Depth 100;$r2bNegative=Get-Content $r2bNegativePath -Raw|ConvertFrom-Json -Depth 100
Assert ($r1bNegative.status -ceq 'pass' -and $r2bNegative.status -ceq 'pass' -and @($r2bNegative.cases|Where-Object id -Like 'evaluated-only-*').Count -eq 2) 'R1/R2 negative evidence incomplete.'
$decisionPath=Join-Path $repo 'docs/guards/inventories/20260924-ifx-c1-applicability-decisions.json'
Assert ((Hash $decisionPath) -ceq 'e3a95670c96992b53438e47c6176ca3c1d6cf111cf4568a90c542cd846218b3d') 'C1m decision drift.'
$applicability=Run 'pwsh' @('-NoProfile','-File',(Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c1m/Test-IFXApplicability.ps1'),'-RepositoryRoot',$repo,'-TargetRoot',$repo) 'C1m applicability'
Assert (((($applicability -join "`n")|ConvertFrom-Json).status) -ceq 'pass') 'C1m applicability failed.'
[void](Run 'pwsh' @('-NoProfile','-File',(Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c1m/tests/Test-IFXApplicability.ps1'),'-RepositoryRoot',$repo) 'C1m drift negatives')
$providerSource=Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c1k/modules/ifx-provider-reference'
$providerConfig=[ordered]@{enabledClaims=@('IFX.C1.PROVIDER_CONTRACT_RAW');policySha256=Hash (Join-Path $providerSource 'policy.json')}
$providerPayload=[ordered]@{formatVersion=1;stage='pre';targetRoot=$repo;packageRoot=$basePackage;relativeRoots=@('src');config=$providerConfig}
$priorStage=$env:V4_STAGE_INPUT_JSON
try{$env:V4_STAGE_INPUT_JSON=$providerPayload|ConvertTo-Json -Depth 20 -Compress;$providerLines=@(& pwsh -NoProfile -File (Join-Path $providerSource 'adapter.ps1') 2>&1);$providerExit=$LASTEXITCODE}finally{$env:V4_STAGE_INPUT_JSON=$priorStage}
Assert ($providerExit -eq 0) "C1k zero-subject adapter failed: $($providerLines -join ' ')"
$providerResult=($providerLines -join "`n")|ConvertFrom-Json -Depth 30
Assert ($providerResult.status -ceq 'fail' -and $providerResult.exitCategory -ceq 'findings-blocking' -and $providerResult.coverage[0].matched -eq 0 -and @($providerResult.findings|Where-Object ruleId -CEQ 'PROVIDER-CONTRACT').Count -eq 1) 'C1k zero-subject detector is not fail-closed.'
$solutionPath=LatestLock 'artifacts/guards/p10-ifx-c5b/solution-runs/*/evidence-lock.json' 'Solution'
$solution=Fresh $solutionPath 'Solution' 86400
$solutionRelative=[IO.Path]::GetRelativePath($repo,$solutionPath).Replace('\','/')
$assemblyId=[guid]::NewGuid().ToString('N')
[void](Run 'pwsh' @('-NoProfile','-File',(Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c5c/Invoke-IFXAssemblyEvidenceProducer.ps1'),'-TargetRoot',$repo,'-SolutionLockPath',$solutionRelative,'-RunId',$assemblyId) 'C5c Assembly producer')
$assemblyRelative="artifacts/guards/p10-ifx-c5c/assembly-runs/$assemblyId/evidence-lock.json";$assemblyPath=Join-Path $repo $assemblyRelative
$assembly=Fresh $assemblyPath 'Assembly' 86400
$typeId=[guid]::NewGuid().ToString('N')
[void](Run 'pwsh' @('-NoProfile','-File',(Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c1r1b/Invoke-IFXCompiledTypeEvidenceProducer.ps1'),'-TargetRoot',$repo,'-SolutionLockPath',$solutionRelative,'-AssemblyLockPath',$assemblyRelative,'-RunId',$typeId) 'R1b type producer')
$typeRelative="artifacts/guards/p10-ifx-c1-r1b/type-runs/$typeId/evidence-lock.json";$typePath=Join-Path $repo $typeRelative
$typeLock=Fresh $typePath 'C1CompiledTypeProvenance' 3600
$graphId=[guid]::NewGuid().ToString('N')
[void](Run 'pwsh' @('-NoProfile','-File',(Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c1r2b/Invoke-IFXEvaluatedGraphProducer.ps1'),'-TargetRoot',$repo,'-RunId',$graphId) 'R2b graph producer')
$graphRelative="artifacts/guards/p10-ifx-c1-r2b/evaluation-runs/$graphId/evidence-lock.json";$graphPath=Join-Path $repo $graphRelative
$graph=Fresh $graphPath 'C1EvaluatedReferenceGraph' 3600
$generatedPath=LatestLock 'artifacts/guards/p10-ifx-c1-r2c/output-runs/*/evidence-lock.json' 'C1GeneratedInputDisposition'
$generated=Fresh $generatedPath 'C1GeneratedInputDisposition' 3600
Assert ($generated.sourceTreeSha256 -ceq $solution.sourceTreeSha256 -and $graph.targetCommit -ceq $typeLock.targetCommit -and $typeLock.targetCommit -ceq $generated.targetCommit) 'Integrated source or commit lineage mismatch.'
Assert ($generated.generatedFileCount -eq 179 -and $generated.generatorOutputCount -eq 4 -and $generated.applicableGeneratedSyntaxSubjectCount -eq 0 -and $generated.v3SourceFilesSha256 -ceq '58e657e7340a58bde2c24efd6f41fa4605eeb09a2d1ab28a1d4847ac739081e2') 'Generated output disposition invalid.'
foreach($file in $generated.generatedFiles){$full=Join-Path $repo $file.path;Assert ([IO.File]::Exists($full) -and (Hash $full) -ceq $file.sha256) "Generated file drift: $($file.path)"}
foreach($item in $generated.analyzers){Assert ([IO.File]::Exists([string]$item.path) -and (Hash ([string]$item.path)) -ceq $item.sha256) 'Analyzer drift.'}
$runId=[guid]::NewGuid().ToString('N')
$runRoot=Join-Path ([IO.Path]::GetTempPath()) "ifx-c1-r3-$runId";[void][IO.Directory]::CreateDirectory($runRoot)
$hostEvidence=Join-Path $runRoot 'host-evidence';[void][IO.Directory]::CreateDirectory($hostEvidence)
$typeDirectory=[IO.Path]::GetDirectoryName($typePath)
Copy-Item -LiteralPath (Join-Path $typeDirectory 'assembly-manifest.json') -Destination (Join-Path $hostEvidence 'assembly-manifest.json')
Copy-Item -LiteralPath (Join-Path $typeDirectory 'assemblies') -Destination (Join-Path $hostEvidence 'assemblies') -Recurse
$bundle=Join-Path $runRoot 'bundle';$package=Join-Path $bundle 'package';[void][IO.Directory]::CreateDirectory((Join-Path $package 'modules'))
$preKeys=@('b','c','d','e','f','g','h','j','n','o');$selections=[Collections.Generic.List[object]]::new();$preIds=[Collections.Generic.List[string]]::new();$rules=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$manifestRows=[Collections.Generic.List[object]]::new();$reviewRows=[Collections.Generic.List[object]]::new();$identity=[Collections.Generic.List[object]]::new()
function AddModule([string]$Source,[string]$Stage,$Config){
    $manifestPath=Join-Path $Source 'module.json';$module=Get-Content $manifestPath -Raw|ConvertFrom-Json -Depth 100
    Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $basePackage 'core/contracts/module.schema.json') -ErrorAction Stop) "Module schema failed: $($module.id)"
    Assert ((Hash (Join-Path $Source 'adapter.ps1')) -ceq $module.adapter.sha256 -and (Hash (Join-Path $Source 'dependencies.lock.json')) -ceq $module.dependencyLock.sha256) "Module executable drift: $($module.id)"
    foreach($authority in $module.authorities){Assert ((Hash (Join-Path $Source ([IO.Path]::GetFileName($authority.path)))) -ceq $authority.sha256) "Module authority drift: $($module.id)/$($authority.id)"}
    $dest=Join-Path $package "modules/$($module.id)";Copy-Item -LiteralPath $Source -Destination $dest -Recurse
    Assert (Test-Json -Json ($Config|ConvertTo-Json -Depth 50 -Compress) -SchemaFile (Join-Path $Source 'config.schema.json') -ErrorAction Stop) "Config schema failed: $($module.id)"
    $selections.Add([ordered]@{id=$module.id;versionRange='>=0.1.0 <1.0.0';config=$Config})
    if($Stage -ceq 'pre'){$preIds.Add($module.id)}
    $plan=Get-Content (Join-Path $Source 'rule-execution-plan.json') -Raw|ConvertFrom-Json -Depth 100
    foreach($rule in $plan.rules){[void]$rules.Add([string]$rule.ruleId);$identity.Add([ordered]@{ruleId=$rule.ruleId;claimId=$rule.claimId;stage=$Stage;module=$module.id;severity=$rule.severity;minimumMatches=$rule.minimumMatches})}
    $ceiling=[ordered]@{readRoots=@($module.capabilities.readRoots);writeRoots=@($module.capabilities.writeRoots);processes=@($module.capabilities.processes);network=[bool]$module.capabilities.network;maxTimeoutSeconds=[int]$module.capabilities.timeoutSeconds}
    $manifestRows.Add([ordered]@{id=$module.id;version=$module.version;manifestPath="modules/$($module.id)/module.json";manifestSha256=Hash (Join-Path $dest 'module.json');allowedCapabilities=$ceiling})
    $reviewRows.Add([ordered]@{moduleId=$module.id;allowedCapabilities=$ceiling})
}
foreach($key in $preKeys){
    $source=(Get-ChildItem (Join-Path $repo "docs/guards/candidates/ifx-gate-coverage-c1$key/modules") -Directory|Select-Object -First 1).FullName
    $policyPath=Join-Path $source 'policy.json';$plan=Get-Content (Join-Path $source 'rule-execution-plan.json') -Raw|ConvertFrom-Json -Depth 100
    $claims=@($plan.rules|ForEach-Object claimId|Select-Object -Unique)
    AddModule $source 'pre' ([ordered]@{enabledClaims=$claims;policySha256=Hash $policyPath})
}
$v3=Get-Content (Join-Path $repo 'docs/guards/V3_ifx/stages/post/rules/ARCH.BINARY.DOMAIN.CONTRACTS.json') -Raw|ConvertFrom-Json
$builtin=[ordered]@{enabledClaims=@('ARCH.TYPE_DEPENDENCY');assemblyManifestPath='assembly-manifest.json';requireFreshBuildEvidence=$false;forbiddenTypeDependencies=@([ordered]@{sourceAssembly=$v3.sourceAssembly;sourceNamespace=$v3.sourceNamespace;forbiddenAssembly=$v3.forbiddenAssembly;forbiddenNamespace=$v3.forbiddenNamespace;minimumMatches=[int]$v3.minimumMatches})}
Assert (Test-Json -Json ($builtin|ConvertTo-Json -Depth 30 -Compress) -SchemaFile (Join-Path $basePackage 'modules/architecture-conformance/config.schema.json') -ErrorAction Stop) 'Built-in type config failed.'
$selections.Add([ordered]@{id='architecture-conformance';versionRange='>=1.0.0 <2.0.0';config=$builtin});[void]$rules.Add('ARCH.TYPE_DEPENDENCY')
$identity.Add([ordered]@{ruleId='ARCH.TYPE_DEPENDENCY';claimId='ARCH.TYPE_DEPENDENCY';stage='post';module='architecture-conformance';severity='blocking';minimumMatches=1})
$typeSource=Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c1r1b/modules/ifx-c1-type-provenance'
AddModule $typeSource 'post' ([ordered]@{enabledClaims=@('IFX.C1.COMPILED_TYPE_PROVENANCE');policySha256=Hash (Join-Path $typeSource 'policy.json');evidenceLockPath=$typeRelative;evidenceLockSha256=Hash $typePath})
$graphSource=Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c1r2b/modules/ifx-c1-evaluated-reference'
AddModule $graphSource 'post' ([ordered]@{enabledClaims=@('IFX.C1.EVALUATED_REFERENCE_GRAPH');policySha256=Hash (Join-Path $graphSource 'policy.json');evidenceLockPath=$graphRelative;evidenceLockSha256=Hash $graphPath})
$postIds=@('architecture-conformance','ifx-c1-type-provenance','ifx-c1-evaluated-reference')
$profileId='ifx_c1_r3_fixture';$profilePath=Join-Path $package "profiles/catalog/$profileId/profile.json"
$profile=[ordered]@{formatVersion=1;id=$profileId;version='0.1.0';projectIdentity=[ordered]@{id='ifx';relativeRoots=@('src','tests','tools','deployment','docs','mcp','artifacts')};moduleSelections=@($selections.ToArray());stageConfiguration=[ordered]@{bootstrap=[ordered]@{enabled=$false;modules=@()};analysis=[ordered]@{enabled=$false;modules=@()};pre=[ordered]@{enabled=$true;modules=@($preIds.ToArray())};post=[ordered]@{enabled=$true;modules=$postIds}};rules=@($rules|Sort-Object);baselineRefs=@()}
Json $profilePath $profile
Assert (Test-Json -LiteralPath $profilePath -SchemaFile (Join-Path $basePackage 'core/contracts/profile.schema.json') -ErrorAction Stop) 'Integrated Profile schema failed.'
$files=@(Get-ChildItem -LiteralPath $package -File -Recurse|Sort-Object FullName|ForEach-Object{[ordered]@{path=[IO.Path]::GetRelativePath($package,$_.FullName).Replace('\','/');sha256=Hash $_.FullName;size=$_.Length}})
$bundleManifest=Join-Path $bundle 'bundle-manifest.json'
Json $bundleManifest ([ordered]@{formatVersion=1;id='ifx-c1-r3-synthetic-extension';version='0.1.0';compatibleApi='1.x';baseVersion='1.1.3';profiles=@([ordered]@{id=$profileId;version='0.1.0';path="profiles/catalog/$profileId/profile.json";sha256=Hash $profilePath});modules=@($manifestRows.ToArray());files=$files})
$review=Join-Path $runRoot 'synthetic-review.json'
Json $review ([ordered]@{formatVersion=1;id='20260924-ifx-c1-r3-synthetic-fixture';scope='synthetic-test-only';decision='accepted';acceptedBy=[ordered]@{authorityType='test-fixture';authorityId='ifx-c1-r3-synthetic-fixture';candidateHostVerdictAllowed=$false};bundleManifestSha256=Hash $bundleManifest;baseArchiveSha256=Hash $archive;moduleCeilings=@($reviewRows.ToArray())})
$composed=Join-Path $runRoot 'composed';$receipt=Join-Path $runRoot 'composition.receipt.json';$state=Join-Path $runRoot 'compose-state';$composeEvidence=Join-Path $runRoot 'compose-evidence';[void][IO.Directory]::CreateDirectory($state);[void][IO.Directory]::CreateDirectory($composeEvidence)
[void](Run 'pwsh' @('-NoProfile','-File',(Join-Path $basePackage 'core/distribution/Compose-V4Extension.ps1'),'-BaseInstallRoot',$BaseInstallRoot,'-BaseReceiptPath',$BaseReceiptPath,'-BaseArchivePath',$archive,'-BundleRoot',$bundle,'-ReviewRecordPath',$review,'-OutputInstallRoot',$composed,'-CompositionReceiptPath',$receipt,'-TargetRoot',$repo,'-StateRoot',$state,'-EvidenceRoot',$composeEvidence,'-AllowSyntheticFixture') 'R3 synthetic composition')
$check=Run 'pwsh' @('-NoProfile','-File',(Join-Path $basePackage 'core/distribution/Test-V4ComposedInstallation.ps1'),'-InstallRoot',$composed,'-ReceiptPath',$receipt,'-BaseReceiptPath',$BaseReceiptPath,'-AllowSyntheticFixture') 'R3 composition receipt'
Assert ((($check -join "`n")|ConvertFrom-Json).status -ceq 'pass') 'R3 composition receipt did not pass.'
$packageBefore=Inventory (Join-Path $composed 'package')
$protected=@($typePath,$graphPath,$generatedPath,(Join-Path $hostEvidence 'assembly-manifest.json'))
foreach($item in $typeLock.assemblies){$protected+=Join-Path $repo $item.sourcePath;$protected+=Join-Path $repo $item.copiedPath;$protected+=Join-Path $hostEvidence "assemblies/$($item.name).dll"}
$inputBefore=@($protected|ForEach-Object{"$_|$(Hash $_)"}) -join "`n"
$cases=[Collections.Generic.List[object]]::new();$coverageRows=[Collections.Generic.List[object]]::new()
foreach($spec in @([ordered]@{id='direct-pre';stage='pre';dependencies=$false},[ordered]@{id='direct-post';stage='post';dependencies=$false},[ordered]@{id='dependency-post';stage='post';dependencies=$true})){
    $hostState=Join-Path $runRoot "host-state-$($spec.id)";[void][IO.Directory]::CreateDirectory($hostState)
    $args=@((Join-Path $composed 'host/v4-guards.dll'),'stage','run','--stage',$spec.stage,'--package-root',(Join-Path $composed 'package'),'--target-root',$repo,'--state-root',$hostState,'--evidence-root',$hostEvidence,'--profile',$profileId)
    if($spec.dependencies){$args+='--with-dependencies'}
    $lines=@(& dotnet @args 2>&1);$raw=$lines -join "`n"
    try{$result=$raw|ConvertFrom-Json -Depth 100}catch{throw "Non-JSON integrated Host ($($spec.id)): $raw"}
    Assert ($LASTEXITCODE -eq 0 -and $result.status -ceq 'pass') "Integrated Host failed ($($spec.id)): $raw"
    $expectedModules=if($spec.id -eq 'direct-pre'){10}elseif($spec.id -eq 'direct-post'){3}else{13}
    Assert (@($result.moduleResults).Count -eq $expectedModules -and @($result.findings).Count -eq 0) "Integrated module/finding drift ($($spec.id)): $raw"
    if($spec.id -eq 'dependency-post'){foreach($row in $result.coverage){$coverageRows.Add($row)}}
    $cases.Add([ordered]@{id=$spec.id;status='pass';modules=$expectedModules;claims=@($result.coverage).Count;matched=(@($result.coverage|Measure-Object -Property matched -Sum)[0].Sum);stages=@($result.executedStages)})
}
Assert ((Inventory (Join-Path $composed 'package')) -ceq $packageBefore -and (@($protected|ForEach-Object{"$_|$(Hash $_)"}) -join "`n") -ceq $inputBefore) 'PackageRoot or protected TargetRoot/evidence input changed.'
$claimIds=@($identity|ForEach-Object claimId|Select-Object -Unique)
foreach($claim in $claimIds){$hits=@($coverageRows|Where-Object claimId -CEQ $claim);Assert ($hits.Count -eq 1 -and $hits[0].matched -ge 1) "Integrated C1 claim is empty or duplicated: $claim"}
Assert (@($coverageRows|Where-Object claimId -CEQ 'ARCH.TYPE_DEPENDENCY')[0].matched -ge 1 -and @($coverageRows|Where-Object claimId -CEQ 'IFX.C1.COMPILED_TYPE_PROVENANCE')[0].matched -eq 7 -and @($coverageRows|Where-Object claimId -CEQ 'IFX.C1.EVALUATED_REFERENCE_GRAPH')[0].matched -eq 147) 'R1/R2 integrated coverage drift.'
$overlaps=@($identity|Group-Object { $_['ruleId'] }|Where-Object Count -gt 1|Sort-Object Name)
Assert (($overlaps.Name -join '|') -ceq 'OWNERSHIP-REFERENCE|RING-DIRECTION|RING-PACKAGE-FORBIDDEN') "Unexpected overlapping canonical rule IDs: $($overlaps.Name -join '|')."
foreach($group in $overlaps){Assert (@($group.Group|ForEach-Object claimId|Select-Object -Unique).Count -eq 2 -and @($group.Group|ForEach-Object module|Select-Object -Unique).Count -eq 2) "Overlap did not retain distinct claims/detectors: $($group.Name)"}
$identity.Add([ordered]@{ruleId='OWNERSHIP-UNKNOWN';claimId='IFX.C1.L2.9_APPLICABILITY';stage='decision';module='C1m';severity='blocking';minimumMatches=0})
$identity.Add([ordered]@{ruleId='PROVIDER-CONTRACT';claimId='IFX.C1.INTEGRATION_ADAPTER_APPLICABILITY';stage='decision';module='C1m';severity='blocking';minimumMatches=0})
$evidence=if([IO.Path]::IsPathFullyQualified($EvidenceRoot)){$EvidenceRoot}else{Join-Path $repo $EvidenceRoot};$report=Join-Path $evidence $runId
Json (Join-Path $report 'summary.json') ([ordered]@{formatVersion=1;status='pass';scope='r3-synthetic-c1-integrated-adjudication';baseVersion='1.1.3';baselineRefs=@();preModuleCount=10;postModuleCount=3;claimCount=$claimIds.Count;boundedApplicabilityCount=2;cases=@($cases.ToArray());identity=@($identity.ToArray());overlappingCanonicalRuleIds=@($overlaps|ForEach-Object name);coverage=@($coverageRows.ToArray());zeroSubjectDetector=[ordered]@{module='ifx-provider-reference';status=$providerResult.status;category=$providerResult.exitCategory;matched=0};evidence=[ordered]@{archiveSha256=Hash $archive;packageHash=$baseCheck.packageHash;profileSha256=Hash $profilePath;compositionReceiptSha256=Hash $receipt;c1c2SummarySha256=Hash $c1c2Path;c5fSummarySha256=Hash $c5fPath;c1mDecisionSha256=Hash $decisionPath;r1bNegativeSummarySha256=Hash $r1bNegativePath;r2bNegativeSummarySha256=Hash $r2bNegativePath;solutionLockPath=$solutionRelative;solutionLockSha256=Hash $solutionPath;assemblyLockPath=$assemblyRelative;assemblyLockSha256=Hash $assemblyPath;typeLockPath=$typeRelative;typeLockSha256=Hash $typePath;graphLockPath=$graphRelative;graphLockSha256=Hash $graphPath;generatedLockPath=[IO.Path]::GetRelativePath($repo,$generatedPath).Replace('\','/');generatedLockSha256=Hash $generatedPath};limitations=@('Synthetic review is not human final-bundle authorization.','P10.3 Diff/CI and G05 Phase 9 remain separate.','C6 requires a separate exact Plan.')})
Write-Output "IFX C1 R3 integrated closure test passed: $report"
