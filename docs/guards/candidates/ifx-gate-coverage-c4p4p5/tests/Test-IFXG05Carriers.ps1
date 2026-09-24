[CmdletBinding()]
param(
    [string]$EvidenceRoot='artifacts/guards/p10-ifx-c4p4p5/test-runs',
    [string]$BaseInstallRoot='D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.3',
    [string]$BaseReceiptPath='D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.3.install.json',
    [string]$BaseArchivePath='artifacts/guards/p10-ifx-c3b/base-archive/v4-guards-1.1.3.zip'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Write-Text([string]$Path,[string]$Value){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,$Value,[Text.UTF8Encoding]::new($false))}
function Write-Json([string]$Path,$Value){Write-Text $Path (($Value|ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n")}
function Inventory([string]$Root){@(Get-ChildItem -LiteralPath $Root -File -Recurse -Force|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"}) -join "`n"}
$candidateRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repo=[IO.Path]::GetFullPath((Join-Path $candidateRoot '../../../..'))
$moduleRoot=Join-Path $candidateRoot 'modules/ifx-g05-carriers'
$adapter=Join-Path $moduleRoot 'adapter.ps1';$policyPath=Join-Path $moduleRoot 'policy.json';$manifestPath=Join-Path $moduleRoot 'module.json'
$policy=Get-Content $policyPath -Raw|ConvertFrom-Json -Depth 100
$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json -Depth 100
$matrix=Get-Content (Join-Path $repo 'docs/guards/inventories/20260924-ifx-c4-g05-claim-matrix.json') -Raw|ConvertFrom-Json -Depth 100
$mapped=@($matrix.claims|Where-Object{$_.source -ceq 'G05 Phase 11' -and $_.phase -in @(4,5)}|ForEach-Object id|Sort-Object)
$actual=@($policy.predicates|ForEach-Object id|Sort-Object)
Assert ($mapped.Count -eq 19 -and ($mapped -join '|') -ceq ($actual -join '|')) 'Phase 4/5 matrix mapping drift.'
Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $BaseInstallRoot 'package/core/contracts/module.schema.json') -ErrorAction Stop) 'Module schema failed.'
Assert ($manifest.id -ceq 'ifx-g05-carriers' -and (@($manifest.stages)-join '|') -ceq 'post' -and (@($manifest.capabilities.readRoots)-join '|') -ceq 'PackageRoot|TargetRoot' -and @($manifest.capabilities.writeRoots).Count -eq 0 -and (@($manifest.capabilities.processes)-join '|') -ceq 'pwsh' -and $manifest.capabilities.network -eq $false) 'Module capabilities drift.'
Assert ((Hash $adapter) -ceq $manifest.adapter.sha256 -and (Hash (Join-Path $moduleRoot 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) 'Adapter/dependency lock drift.'
foreach($a in $manifest.authorities){Assert ((Hash (Join-Path $candidateRoot $a.path)) -ceq $a.sha256) "Module authority drift: $($a.id)"}
$rulePlan=Get-Content (Join-Path $moduleRoot 'rule-execution-plan.json') -Raw|ConvertFrom-Json -Depth 50
Assert ($rulePlan.moduleId -ceq $manifest.id -and @($rulePlan.rules).Count -eq 2 -and @($rulePlan.rules|Where-Object{$_.stage -ceq 'post' -and $_.severity -ceq 'blocking' -and $_.minimumMatches -eq 1 -and $null -eq $_.baseline}).Count -eq 2) 'Blocking rule drift.'
$archive=if([IO.Path]::IsPathFullyQualified($BaseArchivePath)){$BaseArchivePath}else{Join-Path $repo $BaseArchivePath}
Assert ((Hash $archive) -ceq '28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e' -and (Get-Content $BaseReceiptPath -Raw|ConvertFrom-Json).archiveSha256 -ceq (Hash $archive)) 'Published archive/receipt drift.'
$baseCheck=& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/runtime/Test-V4Package.ps1') -PackageRoot (Join-Path $BaseInstallRoot 'package')|ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.packageHash -ceq '9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494') 'Published Package drift.'
$out=if([IO.Path]::IsPathFullyQualified($EvidenceRoot)){$EvidenceRoot}else{Join-Path $repo $EvidenceRoot}
$run=Join-Path $out ([guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($run)
function Config([string]$Root){[ordered]@{enabledClaims=@('IFX.C4.G05_CONTRACT_CARRIER','IFX.C4.G05_EVENT_CARRIER');policySha256=Hash $policyPath;authorityHashes=@($policy.authorities|ForEach-Object{[ordered]@{id=$_.id;sha256=Hash (Join-Path $Root $_.path)}})}}
function Invoke-Adapter([string]$Root,$Configuration){
    $env:V4_STAGE_INPUT_JSON=[ordered]@{formatVersion=1;stage='post';targetRoot=$Root;relativeRoots=@('src','docs','tests');config=$Configuration}|ConvertTo-Json -Depth 50 -Compress
    $output=@(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapter 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Adapter process failed: $($output -join "`n")"
    return (($output -join "`n")|ConvertFrom-Json -Depth 100)
}
function New-Target([string]$Name){
    $root=Join-Path $run "target-$Name";[void][IO.Directory]::CreateDirectory($root)
    foreach($a in $policy.authorities){$to=Join-Path $root $a.path;[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($to));[IO.File]::WriteAllBytes($to,[IO.File]::ReadAllBytes((Join-Path $repo $a.path)))}
    return $root
}
$realConfig=Config $repo
Assert (Test-Json -Json ($realConfig|ConvertTo-Json -Depth 50 -Compress) -SchemaFile (Join-Path $moduleRoot 'config.schema.json') -ErrorAction Stop) 'Config schema failed.'
$realBefore=@($policy.authorities|ForEach-Object{"$($_.id)|$(Hash (Join-Path $repo $_.path))"}) -join "`n"
$real=Invoke-Adapter $repo $realConfig
Assert ($real.status -ceq 'pass' -and @($real.coverage|Where-Object matched -ge 1).Count -eq 2) "Real IFX scan failed: $($real|ConvertTo-Json -Depth 30 -Compress)"
Assert ($realBefore -ceq (@($policy.authorities|ForEach-Object{"$($_.id)|$(Hash (Join-Path $repo $_.path))"}) -join "`n")) 'Real target authority changed.'
$results=[Collections.Generic.List[object]]::new()
$clean=New-Target 'clean';$cleanConfig=Config $clean;$before=Inventory $clean
$cleanResult=Invoke-Adapter $clean $cleanConfig
Assert ($cleanResult.status -ceq 'pass' -and $cleanResult.exitCategory -ceq 'success' -and (Inventory $clean) -ceq $before) 'Clean carrier fixture failed.'
Assert (Test-Json -Json ($cleanResult|ConvertTo-Json -Depth 30 -Compress) -SchemaFile (Join-Path $moduleRoot 'result.schema.json') -ErrorAction Stop) 'Result schema failed.'
$again=Invoke-Adapter $clean $cleanConfig;Assert (($again|ConvertTo-Json -Depth 30 -Compress) -ceq ($cleanResult|ConvertTo-Json -Depth 30 -Compress)) 'Clean adapter nondeterministic.'
$results.Add([ordered]@{id='clean';status=$cleanResult.status;category=$cleanResult.exitCategory})
$badContract=New-Target 'bad-contract';$p=Join-Path $badContract $policy.authorities[0].path;$body=[IO.File]::ReadAllText($p);Assert ($body.Contains('pre-active-conformance')) 'Contract status token missing.';Write-Text $p ($body.Replace('pre-active-conformance','production-approved'))
$badResult=Invoke-Adapter $badContract (Config $badContract)
Assert ($badResult.status -ceq 'fail' -and @($badResult.findings.subject) -contains 'realContractCarrierNotMisrepresented') 'Contract-status negative did not block.'
$results.Add([ordered]@{id='bad-contract-status';status=$badResult.status;category=$badResult.exitCategory})
$badEvent=New-Target 'bad-event';$p=Join-Path $badEvent $policy.authorities[6].path;$body=[IO.File]::ReadAllText($p);Assert ($body.Contains('pre-active-fake-carrier-conformance')) 'Event status token missing.';Write-Text $p ($body.Replace('pre-active-fake-carrier-conformance','production-approved'))
$badEventResult=Invoke-Adapter $badEvent (Config $badEvent)
Assert ($badEventResult.status -ceq 'fail' -and @($badEventResult.findings.subject) -contains 'realMessagingDurabilityNotMisrepresented') 'Event-status negative did not block.'
$results.Add([ordered]@{id='bad-event-status';status=$badEventResult.status;category=$badEventResult.exitCategory})
$zero=New-Target 'zero';foreach($a in $policy.authorities){Write-Text (Join-Path $zero $a.path) ''}
$zeroResult=Invoke-Adapter $zero (Config $zero)
Assert ($zeroResult.status -ceq 'fail' -and @($zeroResult.coverage|Where-Object matched -eq 0).Count -eq 2 -and @($zeroResult.findings.subject) -contains 'zero-subject') 'Zero-subject carrier control did not block.'
$results.Add([ordered]@{id='zero-subject';status=$zeroResult.status;category=$zeroResult.exitCategory})
$missing=New-Target 'missing';[IO.File]::Delete((Join-Path $missing $policy.authorities[0].path))
$missingResult=Invoke-Adapter $missing $cleanConfig
Assert ($missingResult.status -ceq 'error' -and $missingResult.exitCategory -ceq 'prerequisite-missing') 'Missing authority did not block.'
$results.Add([ordered]@{id='missing-authority';status=$missingResult.status;category=$missingResult.exitCategory})
$stale=New-Target 'stale';[IO.File]::AppendAllText((Join-Path $stale $policy.authorities[0].path),' ')
$staleResult=Invoke-Adapter $stale $cleanConfig
Assert ($staleResult.status -ceq 'error' -and $staleResult.exitCategory -ceq 'integrity-failure') 'Stale authority did not block.'
$results.Add([ordered]@{id='stale-authority';status=$staleResult.status;category=$staleResult.exitCategory})
$bundleRoot=Join-Path $run 'bundle';$bundlePackage=Join-Path $bundleRoot 'package';$bundleModule=Join-Path $bundlePackage 'modules/ifx-g05-carriers'
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($bundleModule));Copy-Item -LiteralPath $moduleRoot -Destination $bundleModule -Recurse
$profileId='ifx_c4p4p5_fixture';$profilePath=Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
Write-Json $profilePath ([ordered]@{formatVersion=1;id=$profileId;version='0.1.0';projectIdentity=[ordered]@{id='ifx-c4p4p5-fixture';relativeRoots=@('src','docs','tests')};moduleSelections=@([ordered]@{id='ifx-g05-carriers';versionRange='>=0.1.0 <1.0.0';config=$cleanConfig});stageConfiguration=[ordered]@{bootstrap=[ordered]@{enabled=$false;modules=@()};analysis=[ordered]@{enabled=$false;modules=@()};pre=[ordered]@{enabled=$false;modules=@()};post=[ordered]@{enabled=$true;modules=@('ifx-g05-carriers')}};rules=@('G05-CONTRACT-CARRIER','G05-EVENT-CARRIER');baselineRefs=@()})
$files=@(Get-ChildItem -LiteralPath $bundlePackage -File -Recurse|Sort-Object FullName|ForEach-Object{[ordered]@{path=[IO.Path]::GetRelativePath($bundlePackage,$_.FullName).Replace('\','/');sha256=Hash $_.FullName;size=$_.Length}})
$ceiling=[ordered]@{readRoots=@('PackageRoot','TargetRoot');writeRoots=@();processes=@('pwsh');network=$false;maxTimeoutSeconds=60}
$bundleManifest=Join-Path $bundleRoot 'bundle-manifest.json'
Write-Json $bundleManifest ([ordered]@{formatVersion=1;id='ifx-c4p4p5-synthetic-extension';version='0.1.0';compatibleApi='1.x';baseVersion='1.1.3';profiles=@([ordered]@{id=$profileId;version='0.1.0';path="profiles/catalog/$profileId/profile.json";sha256=Hash $profilePath});modules=@([ordered]@{id='ifx-g05-carriers';version='0.1.0';manifestPath='modules/ifx-g05-carriers/module.json';manifestSha256=Hash (Join-Path $bundleModule 'module.json');allowedCapabilities=$ceiling});files=$files})
$review=Join-Path $run 'synthetic-review.json'
Write-Json $review ([ordered]@{formatVersion=1;id='20260924-ifx-c4p4p5-synthetic-fixture';scope='synthetic-test-only';decision='accepted';acceptedBy=[ordered]@{authorityType='test-fixture';authorityId='ifx-c4p4p5-synthetic-fixture';candidateHostVerdictAllowed=$false};bundleManifestSha256=Hash $bundleManifest;baseArchiveSha256=Hash $archive;moduleCeilings=@([ordered]@{moduleId='ifx-g05-carriers';allowedCapabilities=$ceiling})})
$composed=Join-Path $run 'composed';$receipt=Join-Path $run 'composition.receipt.json';$state=Join-Path $run 'compose-state';$evidence=Join-Path $run 'compose-evidence';[void][IO.Directory]::CreateDirectory($state);[void][IO.Directory]::CreateDirectory($evidence)
$composeOutput=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archive -BundleRoot $bundleRoot -ReviewRecordPath $review -OutputInstallRoot $composed -CompositionReceiptPath $receipt -TargetRoot $clean -StateRoot $state -EvidenceRoot $evidence -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Published Host composition failed: $($composeOutput -join "`n")"
$verify=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $receipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0 -and (($verify -join "`n")|ConvertFrom-Json).status -ceq 'pass') 'Composed receipt check failed.'
$hostState=Join-Path $run 'host-state';$hostEvidence=Join-Path $run 'host-evidence';[void][IO.Directory]::CreateDirectory($hostState);[void][IO.Directory]::CreateDirectory($hostEvidence)
$packageBefore=Inventory (Join-Path $composed 'package');$targetBefore=Inventory $clean
$hostOutput=@(& dotnet (Join-Path $composed 'host/v4-guards.dll') stage run --stage post --package-root (Join-Path $composed 'package') --target-root $clean --state-root $hostState --evidence-root $hostEvidence --profile $profileId 2>&1)
$hostResult=($hostOutput -join "`n")|ConvertFrom-Json -Depth 100
Assert ($LASTEXITCODE -eq 0 -and $hostResult.status -ceq 'pass' -and $hostResult.exitCategory -ceq 'success' -and @($hostResult.coverage|Where-Object matched -ge 1).Count -eq 2) "Host Post failed: $($hostOutput -join "`n")"
Assert ((Inventory (Join-Path $composed 'package')) -ceq $packageBefore -and (Inventory $clean) -ceq $targetBefore) 'Host modified immutable roots.'
Write-Json (Join-Path $run 'summary.json') ([ordered]@{formatVersion=1;status='pass';scope='candidate-c4p4p5';baseVersion='1.1.3';mappedChecks=19;cases=@($results);realCoverage=@($real.coverage);hostCoverage=@($hostResult.coverage);hostComposition='synthetic-only-pass'})
Write-Output "IFX C4p4/p5 19-check carrier candidate and published Host Post passed. Evidence: $run"
