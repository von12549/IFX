[CmdletBinding()]
param(
    [string]$EvidenceRoot='artifacts/guards/p10-ifx-c4b/test-runs',
    [string]$BaseInstallRoot='D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.3',
    [string]$BaseReceiptPath='D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.3.install.json',
    [string]$BaseArchivePath='artifacts/guards/p10-ifx-c3b/base-archive/v4-guards-1.1.3.zip',
    [string]$RealEvidenceLockPath
)
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Hash-Text([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
function Hash-Normalized([string]$Path){Hash-Text ([IO.File]::ReadAllText($Path).ReplaceLineEndings("`n"))}
function Write-Json([string]$Path,$Value){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))}
function Copy-Relative([string]$From,[string]$To,[string]$Relative){$dst=Join-Path $To $Relative;[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dst));[IO.File]::WriteAllBytes($dst,[IO.File]::ReadAllBytes((Join-Path $From $Relative)))}
function Inventory([string]$Root){@(Get-ChildItem -LiteralPath $Root -File -Recurse -Force|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"}) -join "`n"}
function Is-Excluded([string]$Relative,[string[]]$Names){$segments=$Relative.Replace('\','/').Split('/');foreach($segment in $segments){if($Names -ccontains $segment){return $true}};return $false}
function Source-Entries([string]$Root,$Contract){$paths=[Collections.Generic.List[string]]::new();$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal);foreach($relativeRoot in $Contract.roots){$folder=Join-Path $Root $relativeRoot;if(-not [IO.Directory]::Exists($folder)){continue};foreach($file in Get-ChildItem -LiteralPath $folder -File -Recurse -Force){$relative=[IO.Path]::GetRelativePath($Root,$file.FullName).Replace('\','/');if($file.Extension.ToLowerInvariant() -notin @($Contract.extensions) -or (Is-Excluded $relative @($Contract.excludedDirectoryNames))){continue};if(-not $seen.Add($relative)){throw "Duplicate Database source input: $relative"};$paths.Add($relative)}};$ordered=$paths.ToArray();[Array]::Sort($ordered,[StringComparer]::Ordinal);return @($ordered|ForEach-Object{[ordered]@{path=$_;sha256=Hash-Normalized (Join-Path $Root $_)}})}
$candidate=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$repo=[IO.Path]::GetFullPath((Join-Path $candidate '../../../..'))
$module=Join-Path $candidate 'modules/ifx-database-evidence';$adapter=Join-Path $module 'adapter.ps1';$manifestPath=Join-Path $module 'module.json';$policyPath=Join-Path $module 'policy.json'
$inventoryContractPath=Join-Path $module 'source-inventory.json';$inventoryContract=Get-Content $inventoryContractPath -Raw|ConvertFrom-Json -Depth 20
$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json -Depth 50;$policy=Get-Content $policyPath -Raw|ConvertFrom-Json -Depth 50
Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $BaseInstallRoot 'package/core/contracts/module.schema.json') -ErrorAction Stop) 'Module schema failed.'
Assert ($manifest.id -ceq 'ifx-database-evidence' -and (@($manifest.capabilities.readRoots)-join '|') -ceq 'PackageRoot|TargetRoot' -and @($manifest.capabilities.writeRoots).Count -eq 0 -and (@($manifest.capabilities.processes)-join '|') -ceq 'pwsh' -and $manifest.capabilities.network -eq $false) 'Read-only module capability drift.'
Assert ((Hash $adapter) -ceq $manifest.adapter.sha256 -and (Hash (Join-Path $module 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) 'Module byte lock drift.'
foreach($a in $manifest.authorities){Assert ((Hash (Join-Path $candidate $a.path)) -ceq $a.sha256) "Module authority drift: $($a.id)"}
$rulePlan=Get-Content (Join-Path $module 'rule-execution-plan.json') -Raw|ConvertFrom-Json
Assert ($rulePlan.rules.Count -eq 1 -and $rulePlan.rules[0].ruleId -ceq 'DATABASE-LOCKED-EVIDENCE' -and $rulePlan.rules[0].severity -ceq 'blocking' -and $rulePlan.rules[0].minimumMatches -eq 1) 'Blocking rule drift.'
$archive=if([IO.Path]::IsPathFullyQualified($BaseArchivePath)){$BaseArchivePath}else{Join-Path $repo $BaseArchivePath}
Assert ((Hash $archive) -ceq '28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e') 'Published archive drift.'
Assert ((Get-Content $BaseReceiptPath -Raw|ConvertFrom-Json).archiveSha256 -ceq (Hash $archive)) 'Published receipt drift.'
$baseCheck=& pwsh -NoProfile -File (Join-Path $BaseInstallRoot 'package/core/runtime/Test-V4Package.ps1') -PackageRoot (Join-Path $BaseInstallRoot 'package')|ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.packageHash -ceq '9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494') 'Published Package drift.'
$out=if([IO.Path]::IsPathFullyQualified($EvidenceRoot)){$EvidenceRoot}else{Join-Path $repo $EvidenceRoot};$run=Join-Path $out ([guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($run)
$baseline=Join-Path $repo 'docs/guards/V3_ifx/stages/analysis/evidence/refactor-baseline/ci-evidence/run-35055279816/v3-specialized-database/specialized'
$target=Join-Path $run 'target';$prefix='artifacts/guards/p10-ifx-c4b/synthetic/';$evidence=Join-Path $target $prefix
[void][IO.Directory]::CreateDirectory($evidence)
foreach($a in $policy.authorities){Copy-Relative $repo $target $a.path}
$sourceManifest=Get-Content (Join-Path $target 'src/DatabaseMigrator/IFX.DatabaseMigrator/migration-manifest.json') -Raw|ConvertFrom-Json
$inventory=Get-Content (Join-Path $baseline 'database/G02-migration-manifest.json') -Raw|ConvertFrom-Json
foreach($row in @($inventory.modules|ForEach-Object{$_.migrations})){Copy-Relative $repo $target $row.Source}
foreach($name in @('summary.json','database/verification-summary.json','database/migration-safety.json','database/G02-migration-manifest.json','database/G02-database-inventory.json')){Copy-Relative $baseline (Join-Path $evidence 'specialized') $name}
$releaseDir=Join-Path $evidence 'specialized/database/release';[void][IO.Directory]::CreateDirectory($releaseDir)
Copy-Relative $repo $releaseDir 'src/DatabaseMigrator/IFX.DatabaseMigrator/migration-manifest.json'
Move-Item -LiteralPath (Join-Path $releaseDir 'src/DatabaseMigrator/IFX.DatabaseMigrator/migration-manifest.json') -Destination (Join-Path $releaseDir 'migration-manifest.json')
Copy-Relative $repo $releaseDir 'deployment/release-manifest.json'
Move-Item -LiteralPath (Join-Path $releaseDir 'deployment/release-manifest.json') -Destination (Join-Path $releaseDir 'release-manifest.json')
$release=Get-Content (Join-Path $target 'deployment/release-manifest.json') -Raw|ConvertFrom-Json
$scripts=@(foreach($moduleName in @('Auth','CRM','Registry','Holdings','Transaction')){$file="$($moduleName.ToLowerInvariant()).idempotent.sql";$scriptPath=Join-Path $releaseDir $file;[IO.File]::WriteAllText($scriptPath,"-- synthetic C4b fixture $moduleName`n",[Text.UTF8Encoding]::new($false));[ordered]@{module=$moduleName;file=$file;sha256=Hash $scriptPath}})
Write-Json (Join-Path $releaseDir 'artifact-manifest.json') ([ordered]@{releaseVersion=$release.releaseVersion;migrationCatalogSha256=$release.migrationCatalogSha256;scripts=$scripts})
$publish=Join-Path $evidence 'specialized/database/publish/IFX.DatabaseMigrator.dll';[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($publish));[IO.File]::WriteAllText($publish,'synthetic-fixture',[Text.UTF8Encoding]::new($false))
$commit=(& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant()
function Lock([string]$Target,[string]$RelativePrefix,[string]$Started,[string]$Completed){
    $root=Join-Path $Target $RelativePrefix
    $files=@(Get-ChildItem -LiteralPath (Join-Path $root 'specialized') -File -Recurse -Force|Sort-Object FullName|ForEach-Object{[ordered]@{path=[IO.Path]::GetRelativePath($Target,$_.FullName).Replace('\','/');sha256=Hash $_.FullName}})
    $authorities=[ordered]@{};foreach($a in $policy.authorities){$authorities[$a.id]=Hash (Join-Path $Target $a.path)}
    $sourceFiles=@(Source-Entries $Target $inventoryContract);$sourceLines=@($sourceFiles|ForEach-Object{"$($_.path)|$($_.sha256)"});$treeHash=Hash-Text ($sourceLines -join "`n")
    $path=Join-Path $root 'evidence-lock.json';Write-Json $path ([ordered]@{formatVersion=1;gate='Database';producer='ifx-c4b-controlled-v2';result='passed';targetCommit=$commit;startedAt=$Started;completedAt=$Completed;evidencePrefix=$RelativePrefix;sourceInventoryId=$inventoryContract.id;sourceInventorySha256=Hash $inventoryContractPath;sourceFileCount=$sourceLines.Count;sourceTreeSha256=$treeHash;sourceFiles=$sourceFiles;authorityHashes=$authorities;files=$files});return $path
}
$now=[DateTimeOffset]::UtcNow;$lock=Lock $target $prefix $now.AddMinutes(-5).ToString('o') $now.ToString('o')
function Config([string]$Root,[string]$LockPath){[ordered]@{enabledClaims=@('IFX.C4.DATABASE_EVIDENCE');policySha256=Hash $policyPath;authorityHashes=@($policy.authorities|ForEach-Object{[ordered]@{id=$_.id;sha256=Hash (Join-Path $Root $_.path)}});evidenceLockPath=[IO.Path]::GetRelativePath($Root,$LockPath).Replace('\','/');evidenceLockSha256=Hash $LockPath}}
function Invoke-Adapter([string]$Root,$Configuration){$env:V4_STAGE_INPUT_JSON=[ordered]@{formatVersion=1;stage='post';targetRoot=$Root;relativeRoots=@('src','deployment','artifacts');config=$Configuration}|ConvertTo-Json -Depth 50 -Compress;$lines=@(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapter 2>&1);Assert ($LASTEXITCODE -eq 0) "Adapter process failed: $($lines -join "`n")";return (($lines -join "`n")|ConvertFrom-Json -Depth 100)}
$config=Config $target $lock
Assert (Test-Json -Json ($config|ConvertTo-Json -Depth 50 -Compress) -SchemaFile (Join-Path $module 'config.schema.json') -ErrorAction Stop) 'Config schema failed.'
$before=Inventory $target;$clean=Invoke-Adapter $target $config
Assert ($clean.status -ceq 'pass' -and $clean.coverage[0].matched -eq 9 -and (Inventory $target) -ceq $before) "Clean synthetic target failed or changed: $($clean|ConvertTo-Json -Depth 10 -Compress)"
Assert (Test-Json -Json ($clean|ConvertTo-Json -Depth 50 -Compress) -SchemaFile (Join-Path $module 'result.schema.json') -ErrorAction Stop) 'Result schema failed.'
$repeat=Invoke-Adapter $target $config;Assert (($repeat|ConvertTo-Json -Depth 50 -Compress) -ceq ($clean|ConvertTo-Json -Depth 50 -Compress)) 'Nondeterministic result.'
$cases=[Collections.Generic.List[object]]::new();$cases.Add([ordered]@{id='clean-synthetic';status=$clean.status})
$sourceProjectionBefore=@(Source-Entries $target $inventoryContract)|ConvertTo-Json -Depth 10 -Compress
foreach($ignored in @('src/Frontend/IFX.FrontEnd/node_modules/example/package.json','src/Frontend/IFX.FrontEnd/node_modules/.bin/example.ps1','src/Frontend/IFX.FrontEnd/node_modules/.vite/example/results.json')){Write-Json (Join-Path $target $ignored) ([ordered]@{ignored=$true})}
$ignoredResult=Invoke-Adapter $target $config
Assert ($ignoredResult.status -ceq 'pass' -and ((@(Source-Entries $target $inventoryContract)|ConvertTo-Json -Depth 10 -Compress) -ceq $sourceProjectionBefore)) 'Excluded dependency/cache bytes changed the Database inventory.'
$cases.Add([ordered]@{id='ignored-dependency-cache';status=$ignoredResult.status})
$selectedUnexpected=Join-Path $target 'src/DatabaseMigrator/IFX.DatabaseMigrator/untracked-selected.json';Write-Json $selectedUnexpected ([ordered]@{unexpected=$true})
$unexpectedResult=Invoke-Adapter $target $config
Assert ($unexpectedResult.status -ceq 'error' -and $unexpectedResult.exitCategory -ceq 'integrity-failure') 'Untracked selected input did not block.'
[IO.File]::Delete($selectedUnexpected);$cases.Add([ordered]@{id='untracked-selected-input';status=$unexpectedResult.status})
$originalLockBytes=[IO.File]::ReadAllBytes($lock)
function Invoke-LockMutation([string]$Id,[scriptblock]$Mutate){
    try{$value=Get-Content $lock -Raw|ConvertFrom-Json -AsHashtable -Depth 100;& $Mutate $value;Write-Json $lock $value;$result=Invoke-Adapter $target (Config $target $lock);Assert ($result.status -ceq 'error' -and $result.exitCategory -ceq 'integrity-failure') "$Id lock mutation did not block.";return $result}finally{[IO.File]::WriteAllBytes($lock,$originalLockBytes)}
}
$oldProducer=Invoke-LockMutation 'old-producer' {param($v)$v.producer='ifx-c4b-controlled-v1'};$cases.Add([ordered]@{id='old-producer';status=$oldProducer.status})
$wrongContract=Invoke-LockMutation 'wrong-contract' {param($v)$v.sourceInventorySha256='0'*64};$cases.Add([ordered]@{id='wrong-inventory-contract';status=$wrongContract.status})
$reordered=Invoke-LockMutation 'reordered-source-files' {param($v)$copy=@($v.sourceFiles);[Array]::Reverse($copy);$v.sourceFiles=$copy};$cases.Add([ordered]@{id='reordered-source-files';status=$reordered.status})
$duplicate=Invoke-LockMutation 'duplicate-source-file' {param($v)$v.sourceFiles=@($v.sourceFiles)+@($v.sourceFiles[0])};$cases.Add([ordered]@{id='duplicate-source-file';status=$duplicate.status})
$wrongSourceHash=Invoke-LockMutation 'wrong-source-hash' {param($v)$v.sourceFiles[0].sha256='0'*64};$cases.Add([ordered]@{id='wrong-source-hash';status=$wrongSourceHash.status})
$selectedSource=Join-Path $target $inventory.modules[0].migrations[0].Source;$selectedSourceBytes=[IO.File]::ReadAllBytes($selectedSource)
try{[IO.File]::Delete($selectedSource);$missingSelected=Invoke-Adapter $target $config;Assert ($missingSelected.status -ceq 'error' -and $missingSelected.exitCategory -ceq 'integrity-failure') 'Missing selected source did not block.'}finally{[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($selectedSource));[IO.File]::WriteAllBytes($selectedSource,$selectedSourceBytes)}
$cases.Add([ordered]@{id='missing-selected-source';status=$missingSelected.status})
$summaryPath=Join-Path $evidence 'specialized/database/verification-summary.json';$summary=Get-Content $summaryPath -Raw|ConvertFrom-Json -AsHashtable;$summary.checks.sqlServerMatrix=$false;Write-Json $summaryPath $summary
$badLock=Lock $target $prefix $now.AddMinutes(-5).ToString('o') $now.ToString('o');$bad=Invoke-Adapter $target (Config $target $badLock)
Assert ($bad.status -ceq 'fail' -and @($bad.findings.subject) -contains 'sqlServerMatrixPassed') 'False SQL matrix did not block.';$cases.Add([ordered]@{id='false-sql-matrix';status=$bad.status})
Copy-Relative $baseline (Join-Path $evidence 'specialized') 'database/verification-summary.json';$lock=Lock $target $prefix $now.AddMinutes(-5).ToString('o') $now.ToString('o');$config=Config $target $lock
[IO.File]::AppendAllText($summaryPath,' ');$tampered=Invoke-Adapter $target $config
Assert ($tampered.status -ceq 'error' -and $tampered.exitCategory -ceq 'integrity-failure') 'Tampered evidence did not block.';$cases.Add([ordered]@{id='tampered-artifact';status=$tampered.status})
Copy-Relative $baseline (Join-Path $evidence 'specialized') 'database/verification-summary.json';$oldLock=Lock $target $prefix $now.AddHours(-30).ToString('o') $now.AddHours(-25).ToString('o');$stale=Invoke-Adapter $target (Config $target $oldLock)
Assert ($stale.status -ceq 'error' -and $stale.exitCategory -ceq 'integrity-failure') 'Stale evidence did not block.';$cases.Add([ordered]@{id='stale-evidence';status=$stale.status})
$lock=Lock $target $prefix $now.AddMinutes(-5).ToString('o') $now.ToString('o');$config=Config $target $lock
[IO.File]::Delete((Join-Path $releaseDir 'auth.idempotent.sql'));$missing=Invoke-Adapter $target $config
Assert ($missing.status -ceq 'error' -and $missing.exitCategory -ceq 'prerequisite-missing') 'Missing SQL script did not block.';$cases.Add([ordered]@{id='missing-script';status=$missing.status})
foreach($file in (Get-ChildItem -LiteralPath $releaseDir -File -Filter '*.sql')){[IO.File]::Delete($file.FullName)}
$zeroLock=Lock $target $prefix $now.AddMinutes(-5).ToString('o') $now.ToString('o');$zero=Invoke-Adapter $target (Config $target $zeroLock)
Assert ($zero.status -ne 'pass') 'Zero SQL scripts did not block.';$cases.Add([ordered]@{id='zero-scripts';status=$zero.status})
foreach($script in $scripts){[IO.File]::WriteAllText((Join-Path $releaseDir $script.file),"-- synthetic C4b fixture $($script.module)`n",[Text.UTF8Encoding]::new($false))}
[IO.File]::WriteAllText((Join-Path $releaseDir 'auth.idempotent.sql'),"-- synthetic C4b fixture Auth`n",[Text.UTF8Encoding]::new($false));$lock=Lock $target $prefix $now.AddMinutes(-5).ToString('o') $now.ToString('o');$config=Config $target $lock
$source=Join-Path $target $inventory.modules[0].migrations[0].Source;[IO.File]::AppendAllText($source,' ');$sourceDrift=Invoke-Adapter $target $config
Assert ($sourceDrift.status -ne 'pass') 'Source drift did not block.';$cases.Add([ordered]@{id='migration-source-drift';status=$sourceDrift.status})
Copy-Relative $repo $target $inventory.modules[0].migrations[0].Source
$missingLockConfig=Config $target $lock;[IO.File]::Delete($lock);$missingLock=Invoke-Adapter $target $missingLockConfig
Assert ($missingLock.status -ceq 'error' -and $missingLock.exitCategory -ceq 'prerequisite-missing') 'Missing lock did not block.';$cases.Add([ordered]@{id='missing-lock';status=$missingLock.status})
$lock=Lock $target $prefix $now.AddMinutes(-5).ToString('o') $now.ToString('o');$config=Config $target $lock
$realCoverage=@()
if($RealEvidenceLockPath){
    $realLock=if([IO.Path]::IsPathFullyQualified($RealEvidenceLockPath)){$RealEvidenceLockPath}else{Join-Path $repo $RealEvidenceLockPath}
    $realConfig=Config $repo $realLock;$realBefore=@($policy.authorities|ForEach-Object{Hash (Join-Path $repo $_.path)}) -join '|';$realLockBefore=Hash $realLock
    $real=Invoke-Adapter $repo $realConfig
    Assert ($real.status -ceq 'pass' -and $real.coverage[0].matched -eq 9 -and $realLockBefore -ceq (Hash $realLock) -and $realBefore -ceq (@($policy.authorities|ForEach-Object{Hash (Join-Path $repo $_.path)}) -join '|')) "Real IFX locked Database evidence failed or changed: $($real|ConvertTo-Json -Depth 10 -Compress)"
    $realCoverage=@($real.coverage)
    $cases.Add([ordered]@{id='real-locked-evidence';status=$real.status})
}
$bundle=Join-Path $run 'bundle';$bundlePackage=Join-Path $bundle 'package';$bundleModule=Join-Path $bundlePackage 'modules/ifx-database-evidence'
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($bundleModule));Copy-Item -LiteralPath $module -Destination $bundleModule -Recurse
$profileId='ifx_c4b_fixture';$profilePath=Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
Write-Json $profilePath ([ordered]@{formatVersion=1;id=$profileId;version='0.1.0';projectIdentity=[ordered]@{id='ifx-c4b-fixture';relativeRoots=@('src','deployment','artifacts')};moduleSelections=@([ordered]@{id='ifx-database-evidence';versionRange='>=0.1.0 <1.0.0';config=$config});stageConfiguration=[ordered]@{bootstrap=[ordered]@{enabled=$false;modules=@()};analysis=[ordered]@{enabled=$false;modules=@()};pre=[ordered]@{enabled=$false;modules=@()};post=[ordered]@{enabled=$true;modules=@('ifx-database-evidence')}};rules=@('DATABASE-LOCKED-EVIDENCE');baselineRefs=@()})
$bundleFiles=@(Get-ChildItem -LiteralPath $bundlePackage -File -Recurse|Sort-Object FullName|ForEach-Object{[ordered]@{path=[IO.Path]::GetRelativePath($bundlePackage,$_.FullName).Replace('\','/');sha256=Hash $_.FullName;size=$_.Length}})
$ceiling=[ordered]@{readRoots=@('PackageRoot','TargetRoot');writeRoots=@();processes=@('pwsh');network=$false;maxTimeoutSeconds=60}
$bundleManifest=Join-Path $bundle 'bundle-manifest.json'
Write-Json $bundleManifest ([ordered]@{formatVersion=1;id='ifx-c4b-synthetic-extension';version='0.1.0';compatibleApi='1.x';baseVersion='1.1.3';profiles=@([ordered]@{id=$profileId;version='0.1.0';path="profiles/catalog/$profileId/profile.json";sha256=Hash $profilePath});modules=@([ordered]@{id='ifx-database-evidence';version=$manifest.version;manifestPath='modules/ifx-database-evidence/module.json';manifestSha256=Hash (Join-Path $bundleModule 'module.json');allowedCapabilities=$ceiling});files=$bundleFiles})
$review=Join-Path $run 'synthetic-review.json'
Write-Json $review ([ordered]@{formatVersion=1;id='20260924-ifx-c4b-synthetic-fixture';scope='synthetic-test-only';decision='accepted';acceptedBy=[ordered]@{authorityType='test-fixture';authorityId='ifx-c4b-synthetic-fixture';candidateHostVerdictAllowed=$false};bundleManifestSha256=Hash $bundleManifest;baseArchiveSha256=Hash $archive;moduleCeilings=@([ordered]@{moduleId='ifx-database-evidence';allowedCapabilities=$ceiling})})
$composed=Join-Path $run 'composed';$receipt=Join-Path $run 'composition.receipt.json';$state=Join-Path $run 'compose-state';$hostEvidence=Join-Path $run 'compose-evidence';[void][IO.Directory]::CreateDirectory($state);[void][IO.Directory]::CreateDirectory($hostEvidence)
$compose=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archive -BundleRoot $bundle -ReviewRecordPath $review -OutputInstallRoot $composed -CompositionReceiptPath $receipt -TargetRoot $target -StateRoot $state -EvidenceRoot $hostEvidence -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Published Host composition failed: $($compose -join "`n")"
$verify=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $receipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0 -and (($verify -join "`n")|ConvertFrom-Json).status -ceq 'pass') 'Composed receipt check failed.'
$hostState=Join-Path $run 'host-state';$hostEvidence=Join-Path $run 'host-evidence';[void][IO.Directory]::CreateDirectory($hostState);[void][IO.Directory]::CreateDirectory($hostEvidence)
$packageBefore=Inventory (Join-Path $composed 'package');$targetBefore=Inventory $target
$hostLines=@(& dotnet (Join-Path $composed 'host/v4-guards.dll') stage run --stage post --package-root (Join-Path $composed 'package') --target-root $target --state-root $hostState --evidence-root $hostEvidence --profile $profileId 2>&1)
$hostResult=($hostLines -join "`n")|ConvertFrom-Json -Depth 100
Assert ($LASTEXITCODE -eq 0 -and $hostResult.status -ceq 'pass' -and @($hostResult.coverage|Where-Object matched -eq 9).Count -eq 1) "Host Post failed: $($hostLines -join "`n")"
Assert ((Inventory (Join-Path $composed 'package')) -ceq $packageBefore -and (Inventory $target) -ceq $targetBefore) 'Host changed an immutable root.'
Write-Json (Join-Path $run 'summary.json') ([ordered]@{formatVersion=1;status='pass';scope='candidate-c4b-synthetic';baseVersion='1.1.3';mappedChecks=9;cases=@($cases);realCoverage=$realCoverage;hostCoverage=@($hostResult.coverage);hostComposition='synthetic-only-pass'})
Write-Output "IFX C4b locked Database evidence candidate and published Host Post passed. Evidence: $run"
