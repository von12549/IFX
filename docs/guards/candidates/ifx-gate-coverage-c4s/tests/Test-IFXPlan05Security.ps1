[CmdletBinding()]
param(
    [string]$EvidenceRoot='artifacts/guards/p10-ifx-c4s/test-runs',
    [string]$BaseInstallRoot='D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.3',
    [string]$BaseReceiptPath='D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.3.install.json',
    [string]$BaseArchivePath='artifacts/guards/p10-ifx-c3b/base-archive/v4-guards-1.1.3.zip'
)
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Hash-Text([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
function Write-Json([string]$Path,$Value){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))}
function Files([string]$Root){@(Get-ChildItem -LiteralPath (Join-Path $Root 'src') -File -Recurse -Force|Where-Object{$_.Extension -in '.cs','.csproj' -and $_.FullName -notmatch '[\\/](bin|obj)[\\/]'}|Sort-Object FullName)}
function Tree-Hash([string]$Root){Hash-Text (@(Files $Root|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"}) -join "`n")}
function Inventory([string]$Root){@(Get-ChildItem -LiteralPath $Root -File -Recurse -Force|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"}) -join "`n"}
$candidate=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$repo=[IO.Path]::GetFullPath((Join-Path $candidate '../../../..'))
$module=Join-Path $candidate 'modules/ifx-plan05-security';$adapter=Join-Path $module 'adapter.ps1';$manifestPath=Join-Path $module 'module.json';$policyPath=Join-Path $module 'policy.json'
$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json -Depth 100;$policy=Get-Content $policyPath -Raw|ConvertFrom-Json -Depth 100
$matrix=Get-Content (Join-Path $repo 'docs/guards/inventories/20260924-ifx-c4-g05-claim-matrix.json') -Raw|ConvertFrom-Json -Depth 100
$mapped=@($matrix.claims|Where-Object destination -CEQ 'C4-G05-security'|ForEach-Object id)
Assert ($mapped.Count -eq 13 -and ($mapped -join '|') -ceq (@($policy.checkIds) -join '|')) 'Plan05 matrix mapping drift.'
Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $BaseInstallRoot 'package/core/contracts/module.schema.json') -ErrorAction Stop) 'Module schema failed.'
Assert ($manifest.id -ceq 'ifx-plan05-security' -and (@($manifest.capabilities.readRoots)-join '|') -ceq 'PackageRoot|TargetRoot' -and @($manifest.capabilities.writeRoots).Count -eq 0 -and $manifest.capabilities.network -eq $false) 'Module capabilities drift.'
Assert ((Hash $adapter) -ceq $manifest.adapter.sha256 -and (Hash (Join-Path $module 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) 'Module byte lock drift.'
foreach($authority in $manifest.authorities){Assert ((Hash (Join-Path $candidate $authority.path)) -ceq $authority.sha256) "Module authority drift: $($authority.id)"}
$rulePlan=Get-Content (Join-Path $module 'rule-execution-plan.json') -Raw|ConvertFrom-Json -Depth 30
Assert (@($rulePlan.rules).Count -eq 1 -and $rulePlan.rules[0].ruleId -ceq 'PLAN05-SECURITY-BOUNDARY' -and $rulePlan.rules[0].claimId -ceq 'IFX.C4.PLAN05_SECURITY' -and $rulePlan.rules[0].minimumMatches -eq 1) 'Blocking rule drift.'
$archive=if([IO.Path]::IsPathFullyQualified($BaseArchivePath)){$BaseArchivePath}else{Join-Path $repo $BaseArchivePath}
Assert ((Hash $archive) -ceq '28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e') 'Published archive drift.'
Assert ((Get-Content $BaseReceiptPath -Raw|ConvertFrom-Json).archiveSha256 -ceq (Hash $archive)) 'Published receipt drift.'
$baseCheck=& pwsh -NoProfile -File (Join-Path $BaseInstallRoot 'package/core/runtime/Test-V4Package.ps1') -PackageRoot (Join-Path $BaseInstallRoot 'package')|ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.packageHash -ceq '9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494') 'Published Package drift.'
$out=if([IO.Path]::IsPathFullyQualified($EvidenceRoot)){$EvidenceRoot}else{Join-Path $repo $EvidenceRoot};$run=Join-Path $out ([guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($run)
function Config([string]$Root){[ordered]@{enabledClaims=@('IFX.C4.PLAN05_SECURITY');policySha256=Hash $policyPath;authorityHashes=@($policy.authorities|ForEach-Object{[ordered]@{id=$_.id;sha256=Hash (Join-Path $Root $_.path)}});sourceTreeSha256=Tree-Hash $Root}}
function Invoke-Adapter([string]$Root,$Configuration){
    $env:V4_STAGE_INPUT_JSON=[ordered]@{formatVersion=1;stage='post';targetRoot=$Root;relativeRoots=@('src','docs');config=$Configuration}|ConvertTo-Json -Depth 50 -Compress
    $output=@(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapter 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Adapter process failed: $($output -join "`n")"
    return (($output -join "`n")|ConvertFrom-Json -Depth 100)
}
$realConfig=Config $repo
Assert (Test-Json -Json ($realConfig|ConvertTo-Json -Depth 50 -Compress) -SchemaFile (Join-Path $module 'config.schema.json') -ErrorAction Stop) 'Config schema failed.'
$realBefore=@($policy.authorities|ForEach-Object{"$($_.path)|$(Hash (Join-Path $repo $_.path))"}) -join "`n"
$real=Invoke-Adapter $repo $realConfig
Assert ($real.status -ceq 'pass' -and $real.coverage[0].matched -eq 13 -and $realBefore -ceq (@($policy.authorities|ForEach-Object{"$($_.path)|$(Hash (Join-Path $repo $_.path))"}) -join "`n")) 'Real IFX security Post failed or changed authorities.'
function New-Target([string]$Name,[bool]$WithSource){
    $root=Join-Path $run "target-$Name";[void][IO.Directory]::CreateDirectory((Join-Path $root 'src'))
    foreach($authority in $policy.authorities){$to=Join-Path $root $authority.path;[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($to));[IO.File]::WriteAllBytes($to,[IO.File]::ReadAllBytes((Join-Path $repo $authority.path)))}
    if($WithSource){foreach($file in (Files $repo)){$to=Join-Path $root ([IO.Path]::GetRelativePath($repo,$file.FullName));[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($to));[IO.File]::WriteAllBytes($to,[IO.File]::ReadAllBytes($file.FullName))}}
    return $root
}
$cases=[Collections.Generic.List[object]]::new();$cleanTarget=New-Target 'clean' $true;$cleanConfig=Config $cleanTarget;$before=Inventory $cleanTarget
$clean=Invoke-Adapter $cleanTarget $cleanConfig
Assert ($clean.status -ceq 'pass' -and $clean.coverage[0].matched -eq 13 -and (Inventory $cleanTarget) -ceq $before) 'Clean fixture failed or changed.'
Assert (Test-Json -Json ($clean|ConvertTo-Json -Depth 40 -Compress) -SchemaFile (Join-Path $module 'result.schema.json') -ErrorAction Stop) 'Result schema failed.'
$repeat=Invoke-Adapter $cleanTarget $cleanConfig;Assert (($repeat|ConvertTo-Json -Depth 40 -Compress) -ceq ($clean|ConvertTo-Json -Depth 40 -Compress)) 'Nondeterministic result.'
$cases.Add([ordered]@{id='clean';status=$clean.status})
$violate=New-Target 'impure' $true;$contract=Join-Path $violate 'src/Platform/Authentication/IFX.Platform.Authentication.Contracts/IFX.Platform.Authentication.Contracts.csproj'
[IO.File]::AppendAllText($contract,"`n<PackageReference Include=`"Forbidden`" />`n")
$bad=Invoke-Adapter $violate (Config $violate)
Assert ($bad.status -ceq 'fail' -and @($bad.findings.subject) -contains 'AuthenticationContractsArePure') 'Impure-contract negative did not block.'
$cases.Add([ordered]@{id='impure-contract';status=$bad.status})
$zero=New-Target 'zero' $false;$zeroResult=Invoke-Adapter $zero (Config $zero)
Assert ($zeroResult.status -ceq 'fail' -and @($zeroResult.findings.subject) -contains 'AuthenticationContractsArePure' -and @($zeroResult.findings.subject) -contains 'AuthorizationRuntimeHasNoBusinessOrHttpDependency') 'Zero-platform-source did not block.'
$cases.Add([ordered]@{id='zero-platform-source';status=$zeroResult.status})
$missing=New-Target 'missing' $true;[IO.File]::Delete((Join-Path $missing $policy.authorities[0].path))
$missingResult=Invoke-Adapter $missing $cleanConfig
Assert ($missingResult.status -ceq 'error' -and $missingResult.exitCategory -ceq 'prerequisite-missing') 'Missing authority did not block.'
$cases.Add([ordered]@{id='missing-authority';status=$missingResult.status})
$stale=New-Target 'stale' $true;[IO.File]::AppendAllText((Join-Path $stale $policy.authorities[0].path),' ')
$staleResult=Invoke-Adapter $stale $cleanConfig
Assert ($staleResult.status -ceq 'error' -and $staleResult.exitCategory -ceq 'integrity-failure') 'Stale authority did not block.'
$cases.Add([ordered]@{id='stale-authority';status=$staleResult.status})
$bundle=Join-Path $run 'bundle';$bundlePackage=Join-Path $bundle 'package';$bundleModule=Join-Path $bundlePackage 'modules/ifx-plan05-security'
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($bundleModule));Copy-Item -LiteralPath $module -Destination $bundleModule -Recurse
$profileId='ifx_c4s_fixture';$profilePath=Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
Write-Json $profilePath ([ordered]@{formatVersion=1;id=$profileId;version='0.1.0';projectIdentity=[ordered]@{id='ifx-c4s-fixture';relativeRoots=@('src','docs')};moduleSelections=@([ordered]@{id='ifx-plan05-security';versionRange='>=0.1.0 <1.0.0';config=$cleanConfig});stageConfiguration=[ordered]@{bootstrap=[ordered]@{enabled=$false;modules=@()};analysis=[ordered]@{enabled=$false;modules=@()};pre=[ordered]@{enabled=$false;modules=@()};post=[ordered]@{enabled=$true;modules=@('ifx-plan05-security')}};rules=@('PLAN05-SECURITY-BOUNDARY');baselineRefs=@()})
$bundleFiles=@(Get-ChildItem -LiteralPath $bundlePackage -File -Recurse|Sort-Object FullName|ForEach-Object{[ordered]@{path=[IO.Path]::GetRelativePath($bundlePackage,$_.FullName).Replace('\','/');sha256=Hash $_.FullName;size=$_.Length}})
$ceiling=[ordered]@{readRoots=@('PackageRoot','TargetRoot');writeRoots=@();processes=@('pwsh');network=$false;maxTimeoutSeconds=60}
$bundleManifest=Join-Path $bundle 'bundle-manifest.json'
Write-Json $bundleManifest ([ordered]@{formatVersion=1;id='ifx-c4s-synthetic-extension';version='0.1.0';compatibleApi='1.x';baseVersion='1.1.3';profiles=@([ordered]@{id=$profileId;version='0.1.0';path="profiles/catalog/$profileId/profile.json";sha256=Hash $profilePath});modules=@([ordered]@{id='ifx-plan05-security';version='0.1.0';manifestPath='modules/ifx-plan05-security/module.json';manifestSha256=Hash (Join-Path $bundleModule 'module.json');allowedCapabilities=$ceiling});files=$bundleFiles})
$review=Join-Path $run 'synthetic-review.json'
Write-Json $review ([ordered]@{formatVersion=1;id='20260924-ifx-c4s-synthetic-fixture';scope='synthetic-test-only';decision='accepted';acceptedBy=[ordered]@{authorityType='test-fixture';authorityId='ifx-c4s-synthetic-fixture';candidateHostVerdictAllowed=$false};bundleManifestSha256=Hash $bundleManifest;baseArchiveSha256=Hash $archive;moduleCeilings=@([ordered]@{moduleId='ifx-plan05-security';allowedCapabilities=$ceiling})})
$composed=Join-Path $run 'composed';$receipt=Join-Path $run 'composition.receipt.json';$state=Join-Path $run 'compose-state';$evidence=Join-Path $run 'compose-evidence';[void][IO.Directory]::CreateDirectory($state);[void][IO.Directory]::CreateDirectory($evidence)
$compose=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archive -BundleRoot $bundle -ReviewRecordPath $review -OutputInstallRoot $composed -CompositionReceiptPath $receipt -TargetRoot $cleanTarget -StateRoot $state -EvidenceRoot $evidence -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Published Host composition failed: $($compose -join "`n")"
$verify=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $receipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0 -and (($verify -join "`n")|ConvertFrom-Json).status -ceq 'pass') 'Composed receipt check failed.'
$hostState=Join-Path $run 'host-state';$hostEvidence=Join-Path $run 'host-evidence';[void][IO.Directory]::CreateDirectory($hostState);[void][IO.Directory]::CreateDirectory($hostEvidence)
$packageBefore=Inventory (Join-Path $composed 'package');$targetBefore=Inventory $cleanTarget
$hostOutput=@(& dotnet (Join-Path $composed 'host/v4-guards.dll') stage run --stage post --package-root (Join-Path $composed 'package') --target-root $cleanTarget --state-root $hostState --evidence-root $hostEvidence --profile $profileId 2>&1)
$hostResult=($hostOutput -join "`n")|ConvertFrom-Json -Depth 100
Assert ($LASTEXITCODE -eq 0 -and $hostResult.status -ceq 'pass' -and @($hostResult.coverage|Where-Object matched -eq 13).Count -eq 1) "Host Post failed: $($hostOutput -join "`n")"
Assert ((Inventory (Join-Path $composed 'package')) -ceq $packageBefore -and (Inventory $cleanTarget) -ceq $targetBefore) 'Host modified immutable root.'
Write-Json (Join-Path $run 'summary.json') ([ordered]@{formatVersion=1;status='pass';scope='candidate-c4s';baseVersion='1.1.3';mappedChecks=13;cases=@($cases);realCoverage=@($real.coverage);hostCoverage=@($hostResult.coverage);hostComposition='synthetic-only-pass'})
Write-Output "IFX C4s Plan05 security candidate and published Host Post passed. Evidence: $run"
