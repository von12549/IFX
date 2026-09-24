[CmdletBinding()]
param(
    [string]$EvidenceRoot='artifacts/guards/p10-ifx-c1-r1a/test-runs',
    [string]$BaseInstallRoot='D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.3',
    [string]$AssemblyLockPath='artifacts/guards/p10-ifx-c5c/assembly-runs/6a9cf7146fd44434bd476ba1b16b8631/evidence-lock.json'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Write-Json([string]$Path,$Value){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 50).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))}
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
$package=Join-Path $BaseInstallRoot 'package'
$adapter=Join-Path $package 'modules/architecture-conformance/adapter.ps1'
$schema=Join-Path $package 'modules/architecture-conformance/result.schema.json'
Assert ((Hash $adapter) -ceq '227512c6e44cdaf6e391282b05d164abb60e6c89584d414adec72f5cdf07ffe9') 'Installed 1.1.3 adapter drift.'
Assert ((Hash (Join-Path $package 'modules/architecture-conformance/config.schema.json')) -ceq '9ab04c3365adf3b316c703ecb9d86d87dc52a3e3a6016ee9fd09d70d0a7c8830') 'Installed config schema drift.'
Assert ((Hash (Join-Path $repo 'docs/guards/V3_ifx/stages/post/rules/ARCH.BINARY.DOMAIN.CONTRACTS.json')) -ceq 'd5dadf455b9a4b252d3b795c6e34469c0c42d6775473dcae1dd4ea7484b07f4b') 'V3 type authority drift.'
$baseCheck=& pwsh -NoProfile -File (Join-Path $package 'core/runtime/Test-V4Package.ps1') -PackageRoot $package|ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.packageHash -ceq '9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494') 'Published Package drift.'
$lockFull=if([IO.Path]::IsPathFullyQualified($AssemblyLockPath)){$AssemblyLockPath}else{Join-Path $repo $AssemblyLockPath}
Assert ((Hash $lockFull) -ceq '84219a9b215547cdeb37d99586833b5852e948a42450f1405295b8f11c68bd6f') 'C5c lock drift.'
$lock=Get-Content $lockFull -Raw|ConvertFrom-Json -Depth 50
Assert ($lock.gate -ceq 'Assembly' -and $lock.result -ceq 'passed') 'C5c did not pass.'
$crmLock=@($lock.assemblies|Where-Object id -CEQ 'IFX.Modules.CRM.Domain')
Assert ($crmLock.Count -eq 1 -and (Hash (Join-Path $repo $crmLock[0].path)) -ceq $crmLock[0].sha256) 'CRM Domain DLL does not match C5c.'
$rule=Get-Content (Join-Path $repo 'docs/guards/V3_ifx/stages/post/rules/ARCH.BINARY.DOMAIN.CONTRACTS.json') -Raw|ConvertFrom-Json
Assert ($rule.kind -ceq 'forbidden-type-dependency' -and $rule.minimumMatches -eq 1) 'V3 type rule shape drift.'
$runId=[guid]::NewGuid().ToString('N')
$evidence=if([IO.Path]::IsPathFullyQualified($EvidenceRoot)){$EvidenceRoot}else{Join-Path $repo $EvidenceRoot}
$run=Join-Path $evidence $runId
$assemblyDir=Join-Path $run 'assemblies';[void][IO.Directory]::CreateDirectory($assemblyDir)
$sourceFiles=[ordered]@{
    'IFX.Modules.CRM.Domain'='src/Modules/CRM/IFX.Modules.CRM.Domain/bin/Release/net8.0/IFX.Modules.CRM.Domain.dll'
    'IFX.Modules.CRM.Contracts'='src/Modules/CRM/IFX.Modules.CRM.Contracts/bin/Release/net8.0/IFX.Modules.CRM.Contracts.dll'
    'IFX.BuildingBlocks.Domain'='src/Modules/CRM/IFX.Modules.CRM.Domain/bin/Release/net8.0/IFX.BuildingBlocks.Domain.dll'
    'IFX.Platform.Context.Contracts'='src/Modules/CRM/IFX.Modules.CRM.Contracts/bin/Release/net8.0/IFX.Platform.Context.Contracts.dll'
}
$manifest=[ordered]@{formatVersion=1;assemblies=@()}
foreach($name in $sourceFiles.Keys){
    $from=Join-Path $repo $sourceFiles[$name];Assert ([IO.File]::Exists($from)) "Missing source DLL: $name"
    $to=Join-Path $assemblyDir "$name.dll";Copy-Item -LiteralPath $from -Destination $to
    Assert ((Hash $from) -ceq (Hash $to)) "DLL copy drift: $name"
    $manifest.assemblies+=([ordered]@{assemblyName=$name;path="assemblies/$name.dll";sha256=Hash $to})
}
$manifestPath=Join-Path $run 'assembly-manifest.json';Write-Json $manifestPath $manifest
$config=[ordered]@{enabledClaims=@('ARCH.TYPE_DEPENDENCY');assemblyManifestPath='assembly-manifest.json';forbiddenTypeDependencies=@([ordered]@{sourceAssembly=$rule.sourceAssembly;sourceNamespace=$rule.sourceNamespace;forbiddenAssembly=$rule.forbiddenAssembly;forbiddenNamespace=$rule.forbiddenNamespace;minimumMatches=[int]$rule.minimumMatches})}
Assert (Test-Json -Json ($config|ConvertTo-Json -Depth 20 -Compress) -SchemaFile (Join-Path $package 'modules/architecture-conformance/config.schema.json') -ErrorAction Stop) 'Built-in config schema failed.'
$before=@($sourceFiles.Values|ForEach-Object{"$_|$(Hash (Join-Path $repo $_))"}) -join "`n"
function Invoke-Case([string]$Id,$CaseConfig,[string]$Manifest='assembly-manifest.json'){
    $caseRoot=Join-Path $run $Id;[void][IO.Directory]::CreateDirectory($caseRoot)
    Copy-Item -LiteralPath (Join-Path $run 'assemblies') -Destination (Join-Path $caseRoot 'assemblies') -Recurse
    Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $caseRoot 'assembly-manifest.json')
    $payload=[ordered]@{formatVersion=1;stage='post';targetRoot=$repo;packageRoot=$package;evidenceRoot=$caseRoot;relativeRoots=@('src');config=$CaseConfig}
    $prior=$env:V4_STAGE_INPUT_JSON
    try{$env:V4_STAGE_INPUT_JSON=$payload|ConvertTo-Json -Depth 30 -Compress;$output=@(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapter 2>&1);$exit=$LASTEXITCODE}finally{$env:V4_STAGE_INPUT_JSON=$prior}
    Assert ($exit -eq 0) "Adapter process failed ($Id): $($output -join "`n")"
    $raw=$output -join "`n";Assert (Test-Json -Json $raw -SchemaFile $schema -ErrorAction Stop) "Adapter result schema failed: $Id"
    return [ordered]@{root=$caseRoot;result=($raw|ConvertFrom-Json -Depth 50)}
}
$clean=Invoke-Case 'clean' $config
Assert ($clean.result.status -ceq 'pass' -and $clean.result.exitCategory -ceq 'success') "Real CRM compiled check failed: $($clean.result|ConvertTo-Json -Depth 20 -Compress)"
Assert (@($clean.result.coverage|Where-Object{$_.claimId -ceq 'ARCH.TYPE_DEPENDENCY' -and $_.matched -ge 1}).Count -eq 1) 'Real CRM type subjects were vacuous.'
$zeroConfig=$config|ConvertTo-Json -Depth 30|ConvertFrom-Json -AsHashtable -Depth 30
$zeroConfig.forbiddenTypeDependencies[0].sourceNamespace='IFX.Modules.CRM.Domain.Absent'
$zero=Invoke-Case 'zero-subject' $zeroConfig
Assert ($zero.result.status -ceq 'fail' -and $zero.result.exitCategory -ceq 'findings-blocking' -and @($zero.result.coverage|Where-Object matched -EQ 0).Count -eq 1) 'Zero type subjects did not block.'
$missing=Invoke-Case 'missing-dll' $config
$missingManifest=Get-Content (Join-Path $missing.root 'assembly-manifest.json') -Raw|ConvertFrom-Json -AsHashtable
$missingManifest.assemblies[0].path='assemblies/missing.dll';Write-Json (Join-Path $missing.root 'assembly-manifest.json') $missingManifest
$missingResult=Invoke-Case 'missing-dll-check' $config
Copy-Item -LiteralPath (Join-Path $missing.root 'assembly-manifest.json') -Destination (Join-Path $missingResult.root 'assembly-manifest.json') -Force
# Re-run with the altered manifest in the copied case root.
$payload=[ordered]@{formatVersion=1;stage='post';targetRoot=$repo;packageRoot=$package;evidenceRoot=$missingResult.root;relativeRoots=@('src');config=$config}
$prior=$env:V4_STAGE_INPUT_JSON
try{$env:V4_STAGE_INPUT_JSON=$payload|ConvertTo-Json -Depth 30 -Compress;$output=@(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapter 2>&1);$exit=$LASTEXITCODE}finally{$env:V4_STAGE_INPUT_JSON=$prior}
Assert ($exit -eq 0) 'Missing-DLL adapter process failed.'
$missingDoc=($output -join "`n")|ConvertFrom-Json
Assert ($missingDoc.status -ceq 'error' -and $missingDoc.exitCategory -ceq 'prerequisite-missing') 'Missing DLL did not block.'
$altered=Invoke-Case 'altered-hash' $config
$alteredManifest=Get-Content (Join-Path $altered.root 'assembly-manifest.json') -Raw|ConvertFrom-Json -AsHashtable
$alteredManifest.assemblies[0].sha256='0'*64;Write-Json (Join-Path $altered.root 'assembly-manifest.json') $alteredManifest
$payload.evidenceRoot=$altered.root;$prior=$env:V4_STAGE_INPUT_JSON
try{$env:V4_STAGE_INPUT_JSON=$payload|ConvertTo-Json -Depth 30 -Compress;$output=@(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapter 2>&1);$exit=$LASTEXITCODE}finally{$env:V4_STAGE_INPUT_JSON=$prior}
Assert ($exit -eq 0) 'Altered-DLL adapter process failed.'
$alteredDoc=($output -join "`n")|ConvertFrom-Json
Assert ($alteredDoc.status -ceq 'error' -and $alteredDoc.exitCategory -ceq 'integrity-failure') 'Altered hash did not block.'
$after=@($sourceFiles.Values|ForEach-Object{"$_|$(Hash (Join-Path $repo $_))"}) -join "`n"
Assert ($before -ceq $after) 'Probe changed source DLL bytes.'
Write-Json (Join-Path $run 'summary.json') ([ordered]@{formatVersion=1;status='pass';scope='r1a-feasibility-only';baseVersion='1.1.3';ruleAuthoritySha256=Hash (Join-Path $repo 'docs/guards/V3_ifx/stages/post/rules/ARCH.BINARY.DOMAIN.CONTRACTS.json');assemblyLockSha256=Hash $lockFull;cases=@([ordered]@{id='clean';status=$clean.result.status;matched=$clean.result.coverage[0].matched},[ordered]@{id='zero-subject';status=$zero.result.status;exitCategory=$zero.result.exitCategory},[ordered]@{id='missing-dll';status=$missingDoc.status;exitCategory=$missingDoc.exitCategory},[ordered]@{id='altered-hash';status=$alteredDoc.status;exitCategory=$alteredDoc.exitCategory});notes=@('No Host/Profile acceptance','No fresh evidence bridge','No violating type-edge fixture')})
Write-Output "IFX R1a compiled-type feasibility passed: $run"
