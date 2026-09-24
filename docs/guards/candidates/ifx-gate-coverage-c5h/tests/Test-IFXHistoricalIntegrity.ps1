[CmdletBinding()]
param(
    [string]$EvidenceRoot='artifacts/guards/p10-ifx-c5h/test-runs',
    [string]$BaseInstallRoot='D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.3',
    [string]$BaseReceiptPath='D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.3.install.json',
    [string]$BaseArchivePath='artifacts/guards/p10-ifx-c3b/base-archive/v4-guards-1.1.3.zip'
)
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Write-Json([string]$Path,$Value){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))}
function Copy-Relative([string]$From,[string]$To,[string]$Relative){$dst=Join-Path $To $Relative;[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dst));[IO.File]::WriteAllBytes($dst,[IO.File]::ReadAllBytes((Join-Path $From $Relative)))}
function Inventory([string]$Root){@(Get-ChildItem -LiteralPath $Root -File -Recurse -Force|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"}) -join "`n"}
$candidate=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'));$repo=[IO.Path]::GetFullPath((Join-Path $candidate '../../../..'))
$module=Join-Path $candidate 'modules/ifx-history-integrity';$adapter=Join-Path $module 'adapter.ps1';$moduleManifest=Join-Path $module 'module.json';$policyPath=Join-Path $module 'policy.json'
$manifest=Get-Content $moduleManifest -Raw|ConvertFrom-Json -Depth 50;$policy=Get-Content $policyPath -Raw|ConvertFrom-Json -Depth 100
$v3ManifestPath=Join-Path $repo 'docs/guards/V3_ifx/stages/post/gates/historical-integrity/manifest.json';$v3=Get-Content $v3ManifestPath -Raw|ConvertFrom-Json -Depth 100
Assert ((Hash $v3ManifestPath) -ceq $policy.sourceManifestSha256 -and @($policy.entries).Count -eq 15 -and @($policy.references).Count -eq 3) 'V3 history source drift.'
foreach($entry in $policy.entries){$source=@($v3.entries|Where-Object path -CEQ $entry.path);Assert ($source.Count -eq 1 -and $source[0].sha256 -ceq $entry.sha256 -and $source[0].formatVersion -ceq $entry.formatVersion -and $source[0].summary.result -ceq $entry.summary.result -and $source[0].summary.gate -ceq $entry.summary.gate -and $source[0].summary.plan -ceq $entry.summary.plan) "History entry mapping drift: $($entry.path)"}
foreach($reference in $policy.references){Assert (@($v3.references|Where-Object source -CEQ $reference.source|Where-Object target -CEQ $reference.target).Count -eq 1) 'History reference mapping drift.'}
Assert (Test-Json -LiteralPath $moduleManifest -SchemaFile (Join-Path $BaseInstallRoot 'package/core/contracts/module.schema.json') -ErrorAction Stop) 'Module schema failed.'
Assert ($manifest.id -ceq 'ifx-history-integrity' -and (@($manifest.capabilities.readRoots)-join '|') -ceq 'PackageRoot|TargetRoot' -and @($manifest.capabilities.writeRoots).Count -eq 0 -and (@($manifest.capabilities.processes)-join '|') -ceq 'pwsh' -and $manifest.capabilities.network -eq $false) 'History capability drift.'
Assert ((Hash $adapter) -ceq $manifest.adapter.sha256 -and (Hash (Join-Path $module 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) 'Module byte lock drift.'
foreach($a in $manifest.authorities){Assert ((Hash (Join-Path $candidate $a.path)) -ceq $a.sha256) "Module authority drift: $($a.id)"}
$rulePlan=Get-Content (Join-Path $module 'rule-execution-plan.json') -Raw|ConvertFrom-Json
Assert ($rulePlan.rules.Count -eq 1 -and $rulePlan.rules[0].ruleId -ceq 'HISTORY-INTEGRITY' -and $rulePlan.rules[0].minimumMatches -eq 18 -and $rulePlan.rules[0].severity -ceq 'blocking') 'Blocking rule drift.'
$archive=if([IO.Path]::IsPathFullyQualified($BaseArchivePath)){$BaseArchivePath}else{Join-Path $repo $BaseArchivePath}
Assert ((Hash $archive) -ceq '28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e') 'Published archive drift.'
Assert ((Get-Content $BaseReceiptPath -Raw|ConvertFrom-Json).archiveSha256 -ceq (Hash $archive)) 'Published receipt drift.'
$baseCheck=& pwsh -NoProfile -File (Join-Path $BaseInstallRoot 'package/core/runtime/Test-V4Package.ps1') -PackageRoot (Join-Path $BaseInstallRoot 'package')|ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.packageHash -ceq '9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494') 'Published Package drift.'
$out=if([IO.Path]::IsPathFullyQualified($EvidenceRoot)){$EvidenceRoot}else{Join-Path $repo $EvidenceRoot};$run=Join-Path $out ([guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($run)
function Config{[ordered]@{enabledClaims=@('IFX.C5.HISTORY_INTEGRITY');policySha256=Hash $policyPath}}
function Invoke-Adapter([string]$Root,$Configuration){$env:V4_STAGE_INPUT_JSON=[ordered]@{formatVersion=1;stage='post';targetRoot=$Root;relativeRoots=@('mcp','docs');config=$Configuration}|ConvertTo-Json -Depth 50 -Compress;$lines=@(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapter 2>&1);Assert ($LASTEXITCODE -eq 0) "Adapter process failed: $($lines -join "`n")";return (($lines -join "`n")|ConvertFrom-Json -Depth 100)}
$config=Config;Assert (Test-Json -Json ($config|ConvertTo-Json -Depth 30 -Compress) -SchemaFile (Join-Path $module 'config.schema.json') -ErrorAction Stop) 'Config schema failed.'
$realBefore=@($policy.entries|ForEach-Object{Hash (Join-Path $repo $_.path)}) -join '|';$real=Invoke-Adapter $repo $config
Assert ($real.status -ceq 'pass' -and $real.coverage[0].matched -eq 18 -and $realBefore -ceq (@($policy.entries|ForEach-Object{Hash (Join-Path $repo $_.path)}) -join '|')) "Real IFX historical Post failed or changed: $($real|ConvertTo-Json -Depth 10 -Compress)"
$target=Join-Path $run 'target';[void][IO.Directory]::CreateDirectory($target)
foreach($entry in $policy.entries){Copy-Relative $repo $target $entry.path}
foreach($reference in $policy.references){Copy-Relative $repo $target $reference.target}
$before=Inventory $target;$clean=Invoke-Adapter $target $config
Assert ($clean.status -ceq 'pass' -and $clean.coverage[0].matched -eq 18 -and (Inventory $target) -ceq $before) 'Clean history fixture failed or changed.'
Assert (Test-Json -Json ($clean|ConvertTo-Json -Depth 30 -Compress) -SchemaFile (Join-Path $module 'result.schema.json') -ErrorAction Stop) 'Result schema failed.'
$repeat=Invoke-Adapter $target $config;Assert (($repeat|ConvertTo-Json -Depth 30 -Compress) -ceq ($clean|ConvertTo-Json -Depth 30 -Compress)) 'History result nondeterministic.'
$cases=[Collections.Generic.List[object]]::new();$cases.Add([ordered]@{id='real-ifx';status=$real.status});$cases.Add([ordered]@{id='clean-fixture';status=$clean.status})
$first=$policy.entries[0].path;$file=Join-Path $target $first;[IO.File]::AppendAllText($file,' ');$tamper=Invoke-Adapter $target $config
Assert ($tamper.status -ceq 'fail' -and @($tamper.findings.subject) -contains $first) 'Tampered history did not block.';$cases.Add([ordered]@{id='tampered-entry';status=$tamper.status});Copy-Relative $repo $target $first
$canonicalPath=Join-Path $target $policy.entries[8].path;$canonicalText=[IO.File]::ReadAllText($canonicalPath).ReplaceLineEndings("`r`n");[IO.File]::WriteAllText($canonicalPath,$canonicalText,[Text.UTF8Encoding]::new($false))
$canonical=Invoke-Adapter $target $config;Assert ($canonical.status -ceq 'pass') 'Canonical CRLF normalization changed historical verdict.';$cases.Add([ordered]@{id='canonical-line-endings';status=$canonical.status});Copy-Relative $repo $target $policy.entries[8].path
$statusPath=$policy.entries[8].path;$statusFile=Join-Path $target $statusPath;$document=Get-Content $statusFile -Raw|ConvertFrom-Json -AsHashtable;$document.result='failed';Write-Json $statusFile $document
$summaryDrift=Invoke-Adapter $target $config;Assert ($summaryDrift.status -ceq 'fail' -and @($summaryDrift.findings.subject) -contains $statusPath) 'Changed historical summary did not block.';$cases.Add([ordered]@{id='summary-drift';status=$summaryDrift.status});Copy-Relative $repo $target $statusPath
[IO.File]::WriteAllText($statusFile,'{invalid-json',[Text.UTF8Encoding]::new($false));$malformed=Invoke-Adapter $target $config
Assert ($malformed.status -ceq 'fail' -and @($malformed.findings.subject) -contains $statusPath) 'Malformed history JSON did not block.';$cases.Add([ordered]@{id='malformed-json';status=$malformed.status});Copy-Relative $repo $target $statusPath
[IO.File]::Delete($file);$missing=Invoke-Adapter $target $config;Assert ($missing.status -ceq 'fail' -and @($missing.findings.subject) -contains $first) 'Missing history did not block.';$cases.Add([ordered]@{id='missing-entry';status=$missing.status});Copy-Relative $repo $target $first
$referenceOnly=$policy.references[0].target;[IO.File]::Delete((Join-Path $target $referenceOnly));$missingRef=Invoke-Adapter $target $config
Assert ($missingRef.status -ceq 'fail' -and @($missingRef.findings.subject|Where-Object{$_ -like '* -> *'}).Count -gt 0) 'Missing reference did not block.';$cases.Add([ordered]@{id='missing-reference';status=$missingRef.status});Copy-Relative $repo $target $referenceOnly
$zero=Join-Path $run 'zero-target';[void][IO.Directory]::CreateDirectory($zero);$empty=Invoke-Adapter $zero $config
Assert ($empty.status -ceq 'fail' -and @($empty.findings).Count -ge 15) 'Zero-subject target did not block.';$cases.Add([ordered]@{id='zero-history';status=$empty.status})
$staleConfig=Config;$staleConfig.policySha256='0'*64;$stale=Invoke-Adapter $target $staleConfig
Assert ($stale.status -ceq 'error' -and $stale.exitCategory -ceq 'integrity-failure') 'Policy drift did not block.';$cases.Add([ordered]@{id='policy-drift';status=$stale.status})
$bundle=Join-Path $run 'bundle';$bundlePackage=Join-Path $bundle 'package';$bundleModule=Join-Path $bundlePackage 'modules/ifx-history-integrity';[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($bundleModule));Copy-Item -LiteralPath $module -Destination $bundleModule -Recurse
$profileId='ifx_c5h_fixture';$profilePath=Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
Write-Json $profilePath ([ordered]@{formatVersion=1;id=$profileId;version='0.1.0';projectIdentity=[ordered]@{id='ifx-c5h-fixture';relativeRoots=@('mcp','docs')};moduleSelections=@([ordered]@{id='ifx-history-integrity';versionRange='>=0.1.0 <1.0.0';config=$config});stageConfiguration=[ordered]@{bootstrap=[ordered]@{enabled=$false;modules=@()};analysis=[ordered]@{enabled=$false;modules=@()};pre=[ordered]@{enabled=$false;modules=@()};post=[ordered]@{enabled=$true;modules=@('ifx-history-integrity')}};rules=@('HISTORY-INTEGRITY');baselineRefs=@()})
$bundleFiles=@(Get-ChildItem -LiteralPath $bundlePackage -File -Recurse|Sort-Object FullName|ForEach-Object{[ordered]@{path=[IO.Path]::GetRelativePath($bundlePackage,$_.FullName).Replace('\','/');sha256=Hash $_.FullName;size=$_.Length}})
$ceiling=[ordered]@{readRoots=@('PackageRoot','TargetRoot');writeRoots=@();processes=@('pwsh');network=$false;maxTimeoutSeconds=60};$bundleManifest=Join-Path $bundle 'bundle-manifest.json'
Write-Json $bundleManifest ([ordered]@{formatVersion=1;id='ifx-c5h-synthetic-extension';version='0.1.0';compatibleApi='1.x';baseVersion='1.1.3';profiles=@([ordered]@{id=$profileId;version='0.1.0';path="profiles/catalog/$profileId/profile.json";sha256=Hash $profilePath});modules=@([ordered]@{id='ifx-history-integrity';version='0.1.0';manifestPath='modules/ifx-history-integrity/module.json';manifestSha256=Hash (Join-Path $bundleModule 'module.json');allowedCapabilities=$ceiling});files=$bundleFiles})
$review=Join-Path $run 'synthetic-review.json';Write-Json $review ([ordered]@{formatVersion=1;id='20260924-ifx-c5h-synthetic-fixture';scope='synthetic-test-only';decision='accepted';acceptedBy=[ordered]@{authorityType='test-fixture';authorityId='ifx-c5h-synthetic-fixture';candidateHostVerdictAllowed=$false};bundleManifestSha256=Hash $bundleManifest;baseArchiveSha256=Hash $archive;moduleCeilings=@([ordered]@{moduleId='ifx-history-integrity';allowedCapabilities=$ceiling})})
$composed=Join-Path $run 'composed';$receipt=Join-Path $run 'composition.receipt.json';$composeState=Join-Path $run 'compose-state';$composeEvidence=Join-Path $run 'compose-evidence';[void][IO.Directory]::CreateDirectory($composeState);[void][IO.Directory]::CreateDirectory($composeEvidence)
$compose=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archive -BundleRoot $bundle -ReviewRecordPath $review -OutputInstallRoot $composed -CompositionReceiptPath $receipt -TargetRoot $target -StateRoot $composeState -EvidenceRoot $composeEvidence -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Published Host composition failed: $($compose -join "`n")"
$verify=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $receipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0 -and (($verify -join "`n")|ConvertFrom-Json).status -ceq 'pass') 'Composed receipt check failed.'
$hostState=Join-Path $run 'host-state';$hostEvidence=Join-Path $run 'host-evidence';[void][IO.Directory]::CreateDirectory($hostState);[void][IO.Directory]::CreateDirectory($hostEvidence)
$packageBefore=Inventory (Join-Path $composed 'package');$targetBefore=Inventory $target
$hostLines=@(& dotnet (Join-Path $composed 'host/v4-guards.dll') stage run --stage post --package-root (Join-Path $composed 'package') --target-root $target --state-root $hostState --evidence-root $hostEvidence --profile $profileId 2>&1)
$hostResult=($hostLines -join "`n")|ConvertFrom-Json -Depth 100
Assert ($LASTEXITCODE -eq 0 -and $hostResult.status -ceq 'pass' -and @($hostResult.coverage|Where-Object matched -eq 18).Count -eq 1) "Host Post failed: $($hostLines -join "`n")"
Assert ((Inventory (Join-Path $composed 'package')) -ceq $packageBefore -and (Inventory $target) -ceq $targetBefore) 'Host changed immutable roots.'
Write-Json (Join-Path $run 'summary.json') ([ordered]@{formatVersion=1;status='pass';scope='candidate-c5h';baseVersion='1.1.3';historicalEntries=15;referenceEdges=3;cases=@($cases);realCoverage=@($real.coverage);hostCoverage=@($hostResult.coverage);hostComposition='synthetic-only-pass'})
Write-Output "IFX C5h Historical Integrity candidate and published Host Post passed. Evidence: $run"
