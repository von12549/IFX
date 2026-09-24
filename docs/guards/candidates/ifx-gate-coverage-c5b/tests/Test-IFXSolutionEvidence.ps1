[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RealEvidenceLockPath,
    [string]$EvidenceRoot='artifacts/guards/p10-ifx-c5b/test-runs',
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
$candidate=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repo=[IO.Path]::GetFullPath((Join-Path $candidate '../../../..'))
$module=Join-Path $candidate 'modules/ifx-solution-evidence';$adapter=Join-Path $module 'adapter.ps1';$manifestPath=Join-Path $module 'module.json';$policyPath=Join-Path $module 'policy.json'
$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json
Assert (Test-Json -LiteralPath $manifestPath -SchemaFile (Join-Path $BaseInstallRoot 'package/core/contracts/module.schema.json') -ErrorAction Stop) 'Module schema failed.'
Assert ($manifest.id -ceq 'ifx-solution-evidence' -and (@($manifest.capabilities.readRoots)-join '|') -ceq 'PackageRoot|TargetRoot' -and @($manifest.capabilities.writeRoots).Count -eq 0 -and (@($manifest.capabilities.processes)-join '|') -ceq 'pwsh' -and $manifest.capabilities.network -eq $false) 'Read-only capability drift.'
Assert ((Hash $adapter) -ceq $manifest.adapter.sha256 -and (Hash (Join-Path $module 'dependencies.lock.json')) -ceq $manifest.dependencyLock.sha256) 'Module byte lock drift.'
foreach($a in $manifest.authorities){Assert ((Hash (Join-Path $candidate $a.path)) -ceq $a.sha256) "Module authority drift: $($a.id)"}
$rule=Get-Content (Join-Path $module 'rule-execution-plan.json') -Raw|ConvertFrom-Json
Assert ($rule.rules.Count -eq 1 -and $rule.rules[0].minimumMatches -eq 4 -and $rule.rules[0].severity -ceq 'blocking') 'Blocking rule drift.'
$archive=if([IO.Path]::IsPathFullyQualified($BaseArchivePath)){$BaseArchivePath}else{Join-Path $repo $BaseArchivePath}
Assert ((Hash $archive) -ceq '28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e') 'Published archive drift.'
Assert ((Get-Content $BaseReceiptPath -Raw|ConvertFrom-Json).archiveSha256 -ceq (Hash $archive)) 'Published receipt drift.'
$baseCheck=& pwsh -NoProfile -File (Join-Path $BaseInstallRoot 'package/core/runtime/Test-V4Package.ps1') -PackageRoot (Join-Path $BaseInstallRoot 'package')|ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $baseCheck.packageHash -ceq '9dd609291c80f2e66aa44302e31bdc9bfc114b4f52f00e631f7c256c96766494') 'Published Package drift.'
$realLock=if([IO.Path]::IsPathFullyQualified($RealEvidenceLockPath)){$RealEvidenceLockPath}else{Join-Path $repo $RealEvidenceLockPath}
Assert ([IO.File]::Exists($realLock)) 'Real Solution evidence lock missing.'
function Config([string]$Root,[string]$Path){[ordered]@{enabledClaims=@('IFX.C5.SOLUTION_QUALITY');policySha256=Hash $policyPath;evidenceLockPath=[IO.Path]::GetRelativePath($Root,$Path).Replace('\','/');evidenceLockSha256=Hash $Path}}
function Invoke-Adapter([string]$Root,$Configuration){
    $env:V4_STAGE_INPUT_JSON=[ordered]@{formatVersion=1;stage='post';targetRoot=$Root;relativeRoots=@('src','tests','tools','artifacts');config=$Configuration}|ConvertTo-Json -Depth 50 -Compress
    $lines=@(& pwsh -NoLogo -NoProfile -NonInteractive -File $adapter 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Adapter process failed: $($lines -join "`n")"
    return (($lines -join "`n")|ConvertFrom-Json -Depth 100)
}
$config=Config $repo $realLock
Assert (Test-Json -Json ($config|ConvertTo-Json -Depth 50 -Compress) -SchemaFile (Join-Path $module 'config.schema.json') -ErrorAction Stop) 'Config schema failed.'
$realBefore=Hash $realLock;$clean=Invoke-Adapter $repo $config
Assert ($clean.status -ceq 'pass' -and $clean.coverage[0].matched -eq 4 -and (Hash $realLock) -ceq $realBefore) "Real Solution evidence failed: $($clean|ConvertTo-Json -Depth 10 -Compress)"
Assert (Test-Json -Json ($clean|ConvertTo-Json -Depth 50 -Compress) -SchemaFile (Join-Path $module 'result.schema.json') -ErrorAction Stop) 'Result schema failed.'
$repeat=Invoke-Adapter $repo $config
Assert (($repeat|ConvertTo-Json -Depth 50 -Compress) -ceq ($clean|ConvertTo-Json -Depth 50 -Compress)) 'Nondeterministic adapter result.'
$cases=[Collections.Generic.List[object]]::new();$cases.Add([ordered]@{id='real-locked-evidence';status=$clean.status})
$badConfig=[ordered]@{};foreach($k in $config.Keys){$badConfig[$k]=$config[$k]};$badConfig.evidenceLockSha256='0'*64
$tampered=Invoke-Adapter $repo $badConfig
Assert ($tampered.status -ceq 'error' -and $tampered.exitCategory -ceq 'integrity-failure') 'Tampered lock hash did not block.';$cases.Add([ordered]@{id='tampered-lock';status=$tampered.status})
$missingConfig=[ordered]@{};foreach($k in $config.Keys){$missingConfig[$k]=$config[$k]};$missingConfig.evidenceLockPath='artifacts/guards/p10-ifx-c5b/solution-runs/'+('0'*32)+'/evidence-lock.json'
$missing=Invoke-Adapter $repo $missingConfig
Assert ($missing.status -ceq 'error' -and $missing.exitCategory -ceq 'prerequisite-missing') 'Missing lock did not block.';$cases.Add([ordered]@{id='missing-lock';status=$missing.status})
$out=if([IO.Path]::IsPathFullyQualified($EvidenceRoot)){$EvidenceRoot}else{Join-Path $repo $EvidenceRoot};$run=Join-Path $out ([guid]::NewGuid().ToString('N'));[void][IO.Directory]::CreateDirectory($run)
$original=Get-Content $realLock -Raw|ConvertFrom-Json -AsHashtable -Depth 100
function Fixture([string]$Mutation){
    $id=[guid]::NewGuid().ToString('N');$prefix="artifacts/guards/p10-ifx-c5b/solution-runs/$id/"
    $lock=[ordered]@{};foreach($key in $original.Keys){$lock[$key]=$original[$key]};$lock.evidencePrefix=$prefix
    $files=@(foreach($entry in $original.files){
        $relative=([string]$entry.path).Substring(([string]$original.evidencePrefix).Length)
        $destination=Join-Path $repo ($prefix+$relative);[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination));[IO.File]::Copy((Join-Path $repo $entry.path),$destination)
        [ordered]@{path=$prefix+$relative;sha256=Hash $destination}
    })
    $lock.files=$files
    if($Mutation -eq 'zero-tests'){
        $trx=@($files|Where-Object{$_.path -like '*.trx'})|Select-Object -First 1
        $path=Join-Path $repo $trx.path;[xml]$xml=Get-Content $path -Raw;$counters=$xml.SelectSingleNode("//*[local-name()='Counters']");$counters.SetAttribute('total','0');$xml.Save($path);$trx.sha256=Hash $path
    }
    if($Mutation -eq 'failed-summary'){
        $summary=@($files|Where-Object{$_.path -like '*/quality/summary.json'})[0]
        $path=Join-Path $repo $summary.path;$data=Get-Content $path -Raw|ConvertFrom-Json -AsHashtable;$data.status='fail';Write-Json $path $data;$summary.sha256=Hash $path
    }
    if($Mutation -eq 'stale'){$lock.completedAt=([DateTimeOffset]::UtcNow.AddHours(-25)).ToString('o');$lock.startedAt=([DateTimeOffset]::UtcNow.AddHours(-26)).ToString('o')}
    $path=Join-Path $repo ($prefix+'evidence-lock.json');Write-Json $path $lock;return $path
}
foreach($mutation in @('zero-tests','failed-summary','stale')){
    $fixture=Fixture $mutation;$result=Invoke-Adapter $repo (Config $repo $fixture)
    Assert ($result.status -ne 'pass') "$mutation fixture did not block."
    $cases.Add([ordered]@{id=$mutation;status=$result.status;category=$result.exitCategory})
}
$target=Join-Path $run 'target';[void][IO.Directory]::CreateDirectory($target)
foreach($relativeRoot in @('src','tests','tools')){
    Get-ChildItem -LiteralPath (Join-Path $repo $relativeRoot) -File -Recurse -Force |
        Where-Object { $_.Extension -in '.cs','.csproj','.props','.targets' -and $_.FullName -notmatch '[\\/](bin|obj|node_modules|dist)[\\/]' } |
        ForEach-Object {
            $relative=[IO.Path]::GetRelativePath($repo,$_.FullName);$destination=Join-Path $target $relative
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination));[IO.File]::Copy($_.FullName,$destination)
        }
}
[IO.File]::Copy((Join-Path $repo 'IFX.sln'),(Join-Path $target 'IFX.sln'))
$targetLock=Join-Path $target $config.evidenceLockPath
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($targetLock))
Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $realLock) 'quality') -Destination (Split-Path -Parent $targetLock) -Recurse
[IO.File]::Copy($realLock,$targetLock)
$hostConfig=Config $target $targetLock
$hostClean=Invoke-Adapter $target $hostConfig
Assert ($hostClean.status -ceq 'pass') 'Isolated synthetic TargetRoot failed direct Post.'
$bundle=Join-Path $run 'bundle';$bundlePackage=Join-Path $bundle 'package';$bundleModule=Join-Path $bundlePackage 'modules/ifx-solution-evidence'
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($bundleModule));Copy-Item -LiteralPath $module -Destination $bundleModule -Recurse
$profileId='ifx_c5b_fixture';$profilePath=Join-Path $bundlePackage "profiles/catalog/$profileId/profile.json"
Write-Json $profilePath ([ordered]@{formatVersion=1;id=$profileId;version='0.1.0';projectIdentity=[ordered]@{id='ifx-c5b-fixture';relativeRoots=@('src','tests','tools','artifacts')};moduleSelections=@([ordered]@{id='ifx-solution-evidence';versionRange='>=0.1.0 <1.0.0';config=$hostConfig});stageConfiguration=[ordered]@{bootstrap=[ordered]@{enabled=$false;modules=@()};analysis=[ordered]@{enabled=$false;modules=@()};pre=[ordered]@{enabled=$false;modules=@()};post=[ordered]@{enabled=$true;modules=@('ifx-solution-evidence')}};rules=@('SOLUTION-LOCKED-QUALITY');baselineRefs=@()})
$bundleFiles=@(Get-ChildItem -LiteralPath $bundlePackage -File -Recurse|Sort-Object FullName|ForEach-Object{[ordered]@{path=[IO.Path]::GetRelativePath($bundlePackage,$_.FullName).Replace('\','/');sha256=Hash $_.FullName;size=$_.Length}})
$ceiling=[ordered]@{readRoots=@('PackageRoot','TargetRoot');writeRoots=@();processes=@('pwsh');network=$false;maxTimeoutSeconds=180}
$bundleManifest=Join-Path $bundle 'bundle-manifest.json'
Write-Json $bundleManifest ([ordered]@{formatVersion=1;id='ifx-c5b-synthetic-extension';version='0.1.0';compatibleApi='1.x';baseVersion='1.1.3';profiles=@([ordered]@{id=$profileId;version='0.1.0';path="profiles/catalog/$profileId/profile.json";sha256=Hash $profilePath});modules=@([ordered]@{id='ifx-solution-evidence';version='0.1.0';manifestPath='modules/ifx-solution-evidence/module.json';manifestSha256=Hash (Join-Path $bundleModule 'module.json');allowedCapabilities=$ceiling});files=$bundleFiles})
$review=Join-Path $run 'synthetic-review.json'
Write-Json $review ([ordered]@{formatVersion=1;id='20260924-ifx-c5b-synthetic-fixture';scope='synthetic-test-only';decision='accepted';acceptedBy=[ordered]@{authorityType='test-fixture';authorityId='ifx-c5b-synthetic-fixture';candidateHostVerdictAllowed=$false};bundleManifestSha256=Hash $bundleManifest;baseArchiveSha256=Hash $archive;moduleCeilings=@([ordered]@{moduleId='ifx-solution-evidence';allowedCapabilities=$ceiling})})
$composed=Join-Path $run 'composed';$receipt=Join-Path $run 'composition.receipt.json';$state=Join-Path $run 'compose-state';$hostEvidence=Join-Path $run 'compose-evidence';[void][IO.Directory]::CreateDirectory($state);[void][IO.Directory]::CreateDirectory($hostEvidence)
$compose=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $archive -BundleRoot $bundle -ReviewRecordPath $review -OutputInstallRoot $composed -CompositionReceiptPath $receipt -TargetRoot $target -StateRoot $state -EvidenceRoot $hostEvidence -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Published Host composition failed: $($compose -join "`n")"
$verify=@(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $receipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0 -and (($verify -join "`n")|ConvertFrom-Json).status -ceq 'pass') 'Composed receipt check failed.'
$hostState=Join-Path $run 'host-state';$hostEvidence=Join-Path $run 'host-evidence';[void][IO.Directory]::CreateDirectory($hostState);[void][IO.Directory]::CreateDirectory($hostEvidence)
$packageBefore=Inventory (Join-Path $composed 'package');$targetBefore=Inventory $target
$hostLines=@(& dotnet (Join-Path $composed 'host/v4-guards.dll') stage run --stage post --package-root (Join-Path $composed 'package') --target-root $target --state-root $hostState --evidence-root $hostEvidence --profile $profileId 2>&1)
$hostResult=($hostLines -join "`n")|ConvertFrom-Json -Depth 100
Assert ($LASTEXITCODE -eq 0 -and $hostResult.status -ceq 'pass' -and @($hostResult.coverage|Where-Object matched -eq 4).Count -eq 1) "Host Post failed: $($hostLines -join "`n")"
Assert ((Inventory (Join-Path $composed 'package')) -ceq $packageBefore -and (Inventory $target) -ceq $targetBefore) 'Host changed an immutable root.'
Write-Json (Join-Path $run 'summary.json') ([ordered]@{formatVersion=1;status='pass';scope='candidate-c5b-synthetic';baseVersion='1.1.3';mappedChecks=4;cases=@($cases);realCoverage=@($clean.coverage);hostCoverage=@($hostResult.coverage);hostComposition='synthetic-only-pass'})
Write-Output "IFX C5b Solution evidence candidate and published Host Post passed. Evidence: $run"
