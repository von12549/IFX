[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SolutionLockPath,
    [Parameter(Mandatory)][string]$AssemblyLockPath,
    [string]$BaseInstallRoot='D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.3',
    [string]$BaseReceiptPath='D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.3.install.json',
    [string]$BaseArchivePath='artifacts/guards/p10-ifx-c3b/base-archive/v4-guards-1.1.3.zip',
    [string]$EvidenceRoot='artifacts/guards/p10-ifx-c1-r1b/test-runs'
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
$basePackage=Join-Path $BaseInstallRoot 'package'
$baseCheck=& pwsh -NoProfile -File (Join-Path $basePackage 'core/runtime/Test-V4Package.ps1') -PackageRoot $basePackage|ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.packageHash -ceq '9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494') 'Published Package drift.'
$source=Join-Path $candidate 'modules/ifx-c1-type-provenance'
$moduleManifest=Get-Content (Join-Path $source 'module.json') -Raw|ConvertFrom-Json -Depth 100
Assert (Test-Json -LiteralPath (Join-Path $source 'module.json') -SchemaFile (Join-Path $basePackage 'core/contracts/module.schema.json') -ErrorAction Stop) 'Provenance module schema failed.'
Assert ((Hash (Join-Path $source 'adapter.ps1')) -ceq $moduleManifest.adapter.sha256 -and (Hash (Join-Path $source 'dependencies.lock.json')) -ceq $moduleManifest.dependencyLock.sha256) 'Module executable bytes drift.'
foreach($authority in $moduleManifest.authorities){Assert ((Hash (Join-Path $candidate $authority.path)) -ceq $authority.sha256) "Module authority drift: $($authority.id)"}
$runId=[guid]::NewGuid().ToString('N')
$producer=Join-Path $candidate 'Invoke-IFXCompiledTypeEvidenceProducer.ps1'
$lines=@(& pwsh -NoLogo -NoProfile -NonInteractive -File $producer -TargetRoot $repo -SolutionLockPath $SolutionLockPath -AssemblyLockPath $AssemblyLockPath -RunId $runId 2>&1)
Assert ($LASTEXITCODE -eq 0) "Controlled evidence producer failed: $($lines -join "`n")"
$typeEvidence=Join-Path $repo "artifacts/guards/p10-ifx-c1-r1b/type-runs/$runId"
$lockPath=Join-Path $typeEvidence 'evidence-lock.json';$manifestPath=Join-Path $typeEvidence 'assembly-manifest.json'
Assert ([IO.File]::Exists($lockPath) -and [IO.File]::Exists($manifestPath)) 'Controlled evidence missing.'
$lockRelative=[IO.Path]::GetRelativePath($repo,$lockPath).Replace('\','/')
$evidence=if([IO.Path]::IsPathFullyQualified($EvidenceRoot)){$EvidenceRoot}else{Join-Path $repo $EvidenceRoot}
$report=Join-Path $evidence $runId;[void][IO.Directory]::CreateDirectory($report)
$runRoot=Join-Path ([IO.Path]::GetTempPath()) "ifx-c1-r1b-$runId";[void][IO.Directory]::CreateDirectory($runRoot)
$hostEvidence=Join-Path $runRoot 'host-evidence';[void][IO.Directory]::CreateDirectory($hostEvidence)
Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $hostEvidence 'assembly-manifest.json')
Copy-Item -LiteralPath (Join-Path $typeEvidence 'assemblies') -Destination (Join-Path $hostEvidence 'assemblies') -Recurse
$bundle=Join-Path $runRoot 'bundle';$package=Join-Path $bundle 'package';[void][IO.Directory]::CreateDirectory((Join-Path $package 'modules'))
Copy-Item -LiteralPath $source -Destination (Join-Path $package 'modules/ifx-c1-type-provenance') -Recurse
$v3=Get-Content (Join-Path $repo 'docs/guards/V3_ifx/stages/post/rules/ARCH.BINARY.DOMAIN.CONTRACTS.json') -Raw|ConvertFrom-Json
$builtinConfig=[ordered]@{enabledClaims=@('ARCH.TYPE_DEPENDENCY');assemblyManifestPath='assembly-manifest.json';requireFreshBuildEvidence=$false;forbiddenTypeDependencies=@([ordered]@{sourceAssembly=$v3.sourceAssembly;sourceNamespace=$v3.sourceNamespace;forbiddenAssembly=$v3.forbiddenAssembly;forbiddenNamespace=$v3.forbiddenNamespace;minimumMatches=[int]$v3.minimumMatches})}
$provenanceConfig=[ordered]@{enabledClaims=@('IFX.C1.COMPILED_TYPE_PROVENANCE');policySha256=Hash (Join-Path $source 'policy.json');evidenceLockPath=$lockRelative;evidenceLockSha256=Hash $lockPath}
Assert (Test-Json -Json ($builtinConfig|ConvertTo-Json -Depth 50 -Compress) -SchemaFile (Join-Path $basePackage 'modules/architecture-conformance/config.schema.json') -ErrorAction Stop) 'Built-in config schema failed.'
Assert (Test-Json -Json ($provenanceConfig|ConvertTo-Json -Depth 50 -Compress) -SchemaFile (Join-Path $source 'config.schema.json') -ErrorAction Stop) 'Provenance config schema failed.'
$profileId='ifx_c1_r1b_fixture';$profilePath=Join-Path $package "profiles/catalog/$profileId/profile.json"
$profile=[ordered]@{formatVersion=1;id=$profileId;version='0.1.0';projectIdentity=[ordered]@{id='ifx';relativeRoots=@('src','tests','tools','deployment','docs','mcp','artifacts')};moduleSelections=@([ordered]@{id='architecture-conformance';versionRange='>=1.0.0 <2.0.0';config=$builtinConfig},[ordered]@{id='ifx-c1-type-provenance';versionRange='>=0.1.0 <1.0.0';config=$provenanceConfig});stageConfiguration=[ordered]@{bootstrap=[ordered]@{enabled=$false;modules=@()};analysis=[ordered]@{enabled=$false;modules=@()};pre=[ordered]@{enabled=$false;modules=@()};post=[ordered]@{enabled=$true;modules=@('architecture-conformance','ifx-c1-type-provenance')}};rules=@('ARCH.TYPE_DEPENDENCY','C1-COMPILED-TYPE-PROVENANCE');baselineRefs=@()}
Write-Json $profilePath $profile
Assert (Test-Json -LiteralPath $profilePath -SchemaFile (Join-Path $basePackage 'core/contracts/profile.schema.json') -ErrorAction Stop) 'Combined Profile schema failed.'
$files=@(Get-ChildItem -LiteralPath $package -File -Recurse|Sort-Object FullName|ForEach-Object{[ordered]@{path=[IO.Path]::GetRelativePath($package,$_.FullName).Replace('\','/');sha256=Hash $_.FullName;size=$_.Length}})
$manifest=Join-Path $bundle 'bundle-manifest.json'
$ceiling=[ordered]@{readRoots=@('PackageRoot','TargetRoot','EvidenceRoot');writeRoots=@();processes=@('pwsh');network=$false;maxTimeoutSeconds=180}
Write-Json $manifest ([ordered]@{formatVersion=1;id='ifx-c1-r1b-synthetic-extension';version='0.1.0';compatibleApi='1.x';baseVersion='1.1.3';profiles=@([ordered]@{id=$profileId;version='0.1.0';path="profiles/catalog/$profileId/profile.json";sha256=Hash $profilePath});modules=@([ordered]@{id='ifx-c1-type-provenance';version='0.1.0';manifestPath='modules/ifx-c1-type-provenance/module.json';manifestSha256=Hash (Join-Path $package 'modules/ifx-c1-type-provenance/module.json');allowedCapabilities=$ceiling});files=$files})
$review=Join-Path $runRoot 'synthetic-review.json'
Write-Json $review ([ordered]@{formatVersion=1;id='20260924-ifx-c1-r1b-synthetic-fixture';scope='synthetic-test-only';decision='accepted';acceptedBy=[ordered]@{authorityType='test-fixture';authorityId='ifx-c1-r1b-synthetic-fixture';candidateHostVerdictAllowed=$false};bundleManifestSha256=Hash $manifest;baseArchiveSha256=Hash $archive;moduleCeilings=@([ordered]@{moduleId='ifx-c1-type-provenance';allowedCapabilities=$ceiling})})
$composed=Join-Path $runRoot 'composed';$receipt=Join-Path $runRoot 'composition.receipt.json';$state=Join-Path $runRoot 'compose-state';$composeEvidence=Join-Path $runRoot 'compose-evidence'
[void][IO.Directory]::CreateDirectory($state);[void][IO.Directory]::CreateDirectory($composeEvidence)
$output=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $basePackage 'core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archive -BundleRoot $bundle -ReviewRecordPath $review -OutputInstallRoot $composed -CompositionReceiptPath $receipt -TargetRoot $repo -StateRoot $state -EvidenceRoot $composeEvidence -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Synthetic composition failed: $($output -join "`n")"
$verify=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $basePackage 'core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $receipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0 -and (($verify -join "`n")|ConvertFrom-Json).status -ceq 'pass') 'Composed receipt failed.'
$packageBefore=Inventory (Join-Path $composed 'package')
$policy=Get-Content (Join-Path $source 'policy.json') -Raw|ConvertFrom-Json
$protectedPaths=@($lockPath,$manifestPath,(Join-Path $hostEvidence 'assembly-manifest.json'))
foreach($assembly in $policy.assemblies){
    $protectedPaths+=Join-Path $repo $assembly.sourcePath
    $protectedPaths+=Join-Path $typeEvidence "assemblies/$($assembly.name).dll"
    $protectedPaths+=Join-Path $hostEvidence "assemblies/$($assembly.name).dll"
}
$inputsBefore=@($protectedPaths|ForEach-Object{"$_|$(Hash $_)"}) -join "`n"
$cases=[Collections.Generic.List[object]]::new()
foreach($mode in @('direct','dependencies')){
    $hostState=Join-Path $runRoot "host-state-$mode";[void][IO.Directory]::CreateDirectory($hostState)
    $args=@((Join-Path $composed 'host/v4-guards.dll'),'stage','run','--stage','post','--package-root',(Join-Path $composed 'package'),'--target-root',$repo,'--state-root',$hostState,'--evidence-root',$hostEvidence,'--profile',$profileId)
    if($mode -eq 'dependencies'){$args+='--with-dependencies'}
    $lines=@(& dotnet @args 2>&1);$exit=$LASTEXITCODE;$raw=$lines -join "`n"
    try{$result=$raw|ConvertFrom-Json -Depth 100}catch{throw "Non-JSON Host output ($mode): $raw"}
    Assert ($exit -eq 0 -and $result.status -ceq 'pass' -and @($result.moduleResults).Count -eq 2 -and @($result.coverage).Count -eq 2) "Combined Host failed ($mode): $raw"
    Assert (@($result.coverage|Where-Object{$_.claimId -ceq 'ARCH.TYPE_DEPENDENCY' -and $_.matched -ge 1}).Count -eq 1 -and @($result.coverage|Where-Object{$_.claimId -ceq 'IFX.C1.COMPILED_TYPE_PROVENANCE' -and $_.matched -eq 7}).Count -eq 1) "Combined coverage drift ($mode): $raw"
    $stages=if($mode -eq 'dependencies'){'bootstrap|analysis|pre|post'}else{'post'}
    Assert ((@($result.executedStages)-join '|') -ceq $stages) "Stage order drift ($mode)."
    $cases.Add([ordered]@{id=$mode;status=$result.status;compiledMatches=@($result.coverage|Where-Object claimId -CEQ 'ARCH.TYPE_DEPENDENCY')[0].matched;provenanceMatches=7;stages=@($result.executedStages)})
}
function Invoke-ProvenanceNegative([string]$Id,$Config){
    $payload=[ordered]@{formatVersion=1;stage='post';targetRoot=$repo;packageRoot=(Join-Path $composed 'package');evidenceRoot=$hostEvidence;relativeRoots=@('src','tests');config=$Config}
    $prior=$env:V4_STAGE_INPUT_JSON
    try{$env:V4_STAGE_INPUT_JSON=$payload|ConvertTo-Json -Depth 50 -Compress;$lines=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $composed 'package/modules/ifx-c1-type-provenance/adapter.ps1') 2>&1);$code=$LASTEXITCODE}finally{$env:V4_STAGE_INPUT_JSON=$prior}
    Assert ($code -eq 0) "Negative adapter process failed ($Id): $($lines -join "`n")"
    $raw=$lines -join "`n";Assert (Test-Json -Json $raw -SchemaFile (Join-Path $source 'result.schema.json') -ErrorAction Stop) "Negative result schema failed: $Id"
    return $raw|ConvertFrom-Json -Depth 50
}
$missingConfig=$provenanceConfig|ConvertTo-Json -Depth 50|ConvertFrom-Json -AsHashtable -Depth 50
$missingConfig.evidenceLockPath='artifacts/guards/p10-ifx-c1-r1b/type-runs/'+('0'*32)+'/evidence-lock.json'
$missing=Invoke-ProvenanceNegative 'missing-lock' $missingConfig
Assert ($missing.status -ceq 'error' -and $missing.exitCategory -ceq 'prerequisite-missing') 'Missing evidence lock did not block.'
$originalLock=[IO.File]::ReadAllBytes($lockPath)
try{
    $stale=Get-Content $lockPath -Raw|ConvertFrom-Json -AsHashtable -Depth 100
    $stale.createdAt=[DateTimeOffset]::UtcNow.AddHours(-2).ToString('o');$stale.expiresAt=[DateTimeOffset]::UtcNow.AddHours(-1).ToString('o')
    Write-Json $lockPath $stale
    $staleConfig=$provenanceConfig|ConvertTo-Json -Depth 50|ConvertFrom-Json -AsHashtable -Depth 50;$staleConfig.evidenceLockSha256=Hash $lockPath
    $staleResult=Invoke-ProvenanceNegative 'stale-lock' $staleConfig
    Assert ($staleResult.status -ceq 'error' -and $staleResult.exitCategory -ceq 'integrity-failure') 'Stale evidence did not block.'
}finally{[IO.File]::WriteAllBytes($lockPath,$originalLock)}
try{
    $wrongCommit=Get-Content $lockPath -Raw|ConvertFrom-Json -AsHashtable -Depth 100;$wrongCommit.targetCommit='0'*40
    Write-Json $lockPath $wrongCommit
    $wrongCommitConfig=$provenanceConfig|ConvertTo-Json -Depth 50|ConvertFrom-Json -AsHashtable -Depth 50;$wrongCommitConfig.evidenceLockSha256=Hash $lockPath
    $wrongCommitResult=Invoke-ProvenanceNegative 'wrong-commit' $wrongCommitConfig
    Assert ($wrongCommitResult.status -ceq 'error' -and $wrongCommitResult.exitCategory -ceq 'integrity-failure') 'Wrong target commit did not block.'
}finally{[IO.File]::WriteAllBytes($lockPath,$originalLock)}
try{
    $wrong=Get-Content $lockPath -Raw|ConvertFrom-Json -AsHashtable -Depth 100;$wrong.targetFramework='net9.0'
    Write-Json $lockPath $wrong
    $wrongConfig=$provenanceConfig|ConvertTo-Json -Depth 50|ConvertFrom-Json -AsHashtable -Depth 50;$wrongConfig.evidenceLockSha256=Hash $lockPath
    $wrongResult=Invoke-ProvenanceNegative 'wrong-tfm' $wrongConfig
    Assert ($wrongResult.status -ceq 'error' -and $wrongResult.exitCategory -ceq 'integrity-failure') 'Wrong TFM did not block.'
}finally{[IO.File]::WriteAllBytes($lockPath,$originalLock)}
$externalManifestPath=Join-Path $hostEvidence 'assembly-manifest.json';$originalManifest=[IO.File]::ReadAllBytes($externalManifestPath)
try{
    [IO.File]::WriteAllBytes($externalManifestPath,($originalManifest+[byte]10))
    $tampered=Invoke-ProvenanceNegative 'tampered-external-manifest' $provenanceConfig
    Assert ($tampered.status -ceq 'error' -and $tampered.exitCategory -ceq 'integrity-failure') 'Altered external manifest did not block.'
}finally{[IO.File]::WriteAllBytes($externalManifestPath,$originalManifest)}
$zeroConfig=$builtinConfig|ConvertTo-Json -Depth 50|ConvertFrom-Json -AsHashtable -Depth 50
$zeroConfig.forbiddenTypeDependencies[0].sourceNamespace='IFX.Modules.CRM.Domain.Absent'
$zeroInput=[ordered]@{formatVersion=1;stage='post';targetRoot=$repo;packageRoot=(Join-Path $composed 'package');evidenceRoot=$hostEvidence;relativeRoots=@('src');config=$zeroConfig}
$prior=$env:V4_STAGE_INPUT_JSON
try{$env:V4_STAGE_INPUT_JSON=$zeroInput|ConvertTo-Json -Depth 50 -Compress;$zeroLines=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $composed 'package/modules/architecture-conformance/adapter.ps1') 2>&1);$zeroExit=$LASTEXITCODE}finally{$env:V4_STAGE_INPUT_JSON=$prior}
Assert ($zeroExit -eq 0) 'Zero-subject built-in process failed.'
$zeroDoc=($zeroLines -join "`n")|ConvertFrom-Json -Depth 50
Assert ($zeroDoc.status -ceq 'fail' -and $zeroDoc.exitCategory -ceq 'findings-blocking' -and @($zeroDoc.coverage|Where-Object matched -EQ 0).Count -eq 1) 'Zero type subject did not block.'
function Write-Text([string]$Path,[string]$Value){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,$Value,[Text.UTF8Encoding]::new($false))}
$fixture=Join-Path $runRoot 'forbidden-type-fixture';$contracts=Join-Path $fixture 'Contracts';$domain=Join-Path $fixture 'Domain';$fixtureEvidence=Join-Path $fixture 'evidence';$fixtureAssemblies=Join-Path $fixtureEvidence 'assemblies'
foreach($path in @($contracts,$domain,$fixtureAssemblies)){[void][IO.Directory]::CreateDirectory($path)}
Write-Text (Join-Path $contracts 'IFX.Modules.CRM.Contracts.csproj') '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework><AssemblyName>IFX.Modules.CRM.Contracts</AssemblyName></PropertyGroup></Project>'
Write-Text (Join-Path $contracts 'Contract.cs') 'namespace IFX.Modules.CRM.Contracts.V1 { public sealed class ForbiddenType {} }'
Write-Text (Join-Path $domain 'IFX.Modules.CRM.Domain.csproj') '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework><AssemblyName>IFX.Modules.CRM.Domain</AssemblyName></PropertyGroup><ItemGroup><ProjectReference Include="../Contracts/IFX.Modules.CRM.Contracts.csproj" /></ItemGroup></Project>'
Write-Text (Join-Path $domain 'Domain.cs') 'namespace IFX.Modules.CRM.Domain.Entities { public sealed class Entity { public IFX.Modules.CRM.Contracts.V1.ForbiddenType Value { get; } = new(); } }'
$props=@('-p:ImportDirectoryBuildProps=false','-p:ImportDirectoryBuildTargets=false','-p:ImportDirectoryPackagesProps=false','-p:ImportDirectorySolutionProps=false','-p:ImportDirectorySolutionTargets=false')
$restore=@(& dotnet restore (Join-Path $domain 'IFX.Modules.CRM.Domain.csproj') --configfile (Join-Path $basePackage 'build/NuGet.config') -nologo @props 2>&1)
Assert ($LASTEXITCODE -eq 0) "Forbidden fixture restore failed: $($restore -join "`n")"
$build=@(& dotnet build (Join-Path $domain 'IFX.Modules.CRM.Domain.csproj') --no-restore -c Release -o $fixtureAssemblies -nologo @props 2>&1)
Assert ($LASTEXITCODE -eq 0) "Forbidden fixture build failed: $($build -join "`n")"
$fixtureManifest=[ordered]@{formatVersion=1;assemblies=@(foreach($name in @('IFX.Modules.CRM.Contracts','IFX.Modules.CRM.Domain')){[ordered]@{assemblyName=$name;path="assemblies/$name.dll";sha256=Hash (Join-Path $fixtureAssemblies "$name.dll")}})}
Write-Json (Join-Path $fixtureEvidence 'assembly-manifest.json') $fixtureManifest
$violationInput=[ordered]@{formatVersion=1;stage='post';targetRoot=$fixture;packageRoot=(Join-Path $composed 'package');evidenceRoot=$fixtureEvidence;relativeRoots=@('Domain','Contracts');config=$builtinConfig}
$prior=$env:V4_STAGE_INPUT_JSON
try{$env:V4_STAGE_INPUT_JSON=$violationInput|ConvertTo-Json -Depth 50 -Compress;$violationLines=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $composed 'package/modules/architecture-conformance/adapter.ps1') 2>&1);$violationExit=$LASTEXITCODE}finally{$env:V4_STAGE_INPUT_JSON=$prior}
Assert ($violationExit -eq 0) "Forbidden fixture adapter failed: $($violationLines -join "`n")"
$violation=($violationLines -join "`n")|ConvertFrom-Json -Depth 50
Assert ($violation.status -ceq 'fail' -and $violation.exitCategory -ceq 'findings-blocking' -and @($violation.findings|Where-Object ruleId -CEQ 'ARCH.TYPE_DEPENDENCY').Count -eq 1) "Forbidden compiled type edge was not blocked: $($violation|ConvertTo-Json -Depth 30 -Compress)"
$cases.Add([ordered]@{id='missing-lock';status=$missing.status;exitCategory=$missing.exitCategory})
$cases.Add([ordered]@{id='stale-lock';status=$staleResult.status;exitCategory=$staleResult.exitCategory})
$cases.Add([ordered]@{id='wrong-commit';status=$wrongCommitResult.status;exitCategory=$wrongCommitResult.exitCategory})
$cases.Add([ordered]@{id='wrong-tfm';status=$wrongResult.status;exitCategory=$wrongResult.exitCategory})
$cases.Add([ordered]@{id='tampered-external-manifest';status=$tampered.status;exitCategory=$tampered.exitCategory})
$cases.Add([ordered]@{id='zero-type-subject';status=$zeroDoc.status;exitCategory=$zeroDoc.exitCategory})
$cases.Add([ordered]@{id='forbidden-compiled-type-edge';status=$violation.status;exitCategory=$violation.exitCategory})
$inputsAfter=@($protectedPaths|ForEach-Object{"$_|$(Hash $_)"}) -join "`n"
Assert ($inputsBefore -ceq $inputsAfter -and (Inventory (Join-Path $composed 'package')) -ceq $packageBefore) 'Host changed protected evidence or Package bytes.'
Write-Json (Join-Path $report 'summary.json') ([ordered]@{formatVersion=1;status='pass';scope='c1-r1b-synthetic-host';baseVersion='1.1.3';claims=@('ARCH.TYPE_DEPENDENCY','IFX.C1.COMPILED_TYPE_PROVENANCE');baselineRefs=@();evidenceLockPath=$lockRelative;evidenceLockSha256=Hash $lockPath;cases=@($cases.ToArray());packageHash=$baseCheck.packageHash})
Write-Output "IFX C1 R1b combined compiled-type Host passed: $report"
