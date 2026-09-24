[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WindowsSummaryPath,
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$BundleRoot,
    [Parameter(Mandatory)][string]$ReviewRecordPath,
    [Parameter(Mandatory)][string]$TargetRoot,
    [Parameter(Mandatory)][string]$WindowsBaseReceiptPath,
    [Parameter(Mandatory)][string]$BaseArchivePath,
    [Parameter(Mandatory)][string]$WorkRoot,
    [Parameter(Mandatory)][string]$ReportPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function WriteJson([string]$Path,$Value){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))}
function Fingerprint([string]$Root){@(Get-ChildItem -LiteralPath $Root -File -Recurse -Force|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"}) -join "`n"}
Assert ($IsLinux -and ((& dotnet --version).Trim() -ceq '10.0.303')) 'Pinned Linux SDK 10.0.303 required.'
$windows=Get-Content $WindowsSummaryPath -Raw|ConvertFrom-Json -Depth 100
Assert ($windows.status -ceq 'pass' -and $windows.hostValidated -and $windows.baseVersion -ceq '1.1.3' -and $windows.bundleVersion -ceq '0.3.0' -and @($windows.cases).Count -eq 3) 'Windows same-candidate report invalid.'
Assert (-not(Test-Path $TargetRoot)) 'Native Linux TargetRoot must be absent.'
$clone=@(& git clone --no-local --quiet -c core.autocrlf=true $SourceRoot $TargetRoot 2>&1)
Assert ($LASTEXITCODE -eq 0) "Native Linux checkout failed: $($clone -join ' ')"
# Preserve the exact clean Windows worktree bytes. Git checkout EOL conversion
# can otherwise alter source and authority hashes despite the same commit.
$sourceTracked=@(& git -c core.autocrlf=true -c core.filemode=false -C $SourceRoot status --porcelain --untracked-files=no)
Assert ($LASTEXITCODE -eq 0 -and ($sourceTracked -join '').Trim().Length -eq 0) 'Bound Windows source has tracked changes.'
$trackedPaths=@(& git -C $SourceRoot -c core.quotePath=false ls-files)
Assert ($LASTEXITCODE -eq 0 -and $trackedPaths.Count -gt 4000) 'Bound Windows file inventory unavailable.'
foreach($relative in $trackedPaths){
    $sourceFile=Join-Path $SourceRoot $relative;$targetFile=Join-Path $TargetRoot $relative
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $targetFile))
    Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force
}
foreach($relativeRoot in @('src','tests')){
    foreach($dir in @(Get-ChildItem -LiteralPath (Join-Path $SourceRoot $relativeRoot) -Directory -Recurse -Force|Where-Object{$_.FullName -notmatch '[\\/](bin|obj|node_modules|dist|coverage|\.vite)([\\/]|$)'})){
        $relative=[IO.Path]::GetRelativePath($SourceRoot,$dir.FullName)
        [void][IO.Directory]::CreateDirectory((Join-Path $TargetRoot $relative))
    }
}
foreach($entry in $windows.locks){
    $sourceLock=Join-Path $SourceRoot $entry.path
    Assert ((Hash $sourceLock) -ceq $entry.sha256) "Source evidence lock drift: $($entry.id)"
    $sourceDir=Split-Path -Parent $sourceLock
    $targetDir=Join-Path $TargetRoot (Split-Path -Parent $entry.path)
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $targetDir))
    Copy-Item -LiteralPath $sourceDir -Destination $targetDir -Recurse
}
$typeEntry=@($windows.locks|Where-Object id -CEQ 'type');Assert ($typeEntry.Count -eq 1) 'One compiled-type evidence lock required.'
$TypeLockPath=Join-Path $TargetRoot $typeEntry[0].path
$commit=(& git -C $TargetRoot rev-parse HEAD).Trim();Assert ($LASTEXITCODE -eq 0 -and $commit -ceq $windows.sourceCommit) 'Linux TargetRoot source commit drift.'
$manifest=Join-Path $BundleRoot 'bundle-manifest.json';$profile=Join-Path $BundleRoot 'package/profiles/catalog/ifx_profile/profile.json'
Assert ((Hash $manifest) -ceq $windows.bundleManifestSha256 -and (Hash $profile) -ceq $windows.profileSha256) 'Bundle manifest or Profile differs from Windows candidate.'
Assert ((Hash $BaseArchivePath) -ceq '28307116aca1361e9eed5fdcd284a58cdfdb8fd3728869f09dd13f4c9a49b02e') 'Published base archive drift.'
$windowsReceipt=Get-Content $WindowsBaseReceiptPath -Raw|ConvertFrom-Json -Depth 100
Assert ($windowsReceipt.version -ceq '1.1.3' -and $windowsReceipt.archiveSha256 -ceq (Hash $BaseArchivePath)) 'Published Windows base receipt drift.'
$review=Get-Content $ReviewRecordPath -Raw|ConvertFrom-Json -Depth 100
Assert ($review.scope -ceq 'synthetic-test-only' -and $review.bundleManifestSha256 -ceq (Hash $manifest) -and $review.baseArchiveSha256 -ceq (Hash $BaseArchivePath) -and -not $review.acceptedBy.candidateHostVerdictAllowed) 'Synthetic review record mismatch.'
foreach($entry in $windows.locks){Assert ((Hash (Join-Path $TargetRoot $entry.path)) -ceq $entry.sha256) "Evidence lock drift: $($entry.id)"}
$type=Get-Content $TypeLockPath -Raw|ConvertFrom-Json -Depth 100
Assert ($type.gate -ceq 'C1CompiledTypeProvenance' -and $type.targetCommit -ceq $commit) 'Compiled-type lock mismatch.'
$assemblyEntry=@($windows.locks|Where-Object id -CEQ 'assembly');Assert ($assemblyEntry.Count -eq 1) 'One C5 assembly evidence lock required.'
$assembly=Get-Content (Join-Path $TargetRoot $assemblyEntry[0].path) -Raw|ConvertFrom-Json -Depth 100
foreach($row in @(@($type.assemblies|ForEach-Object{[ordered]@{path=$_.sourcePath;sha256=$_.sha256}})+@($assembly.assemblies|ForEach-Object{[ordered]@{path=$_.path;sha256=$_.sha256}}))){
    $sourceDll=Join-Path $SourceRoot $row.path;$targetDll=Join-Path $TargetRoot $row.path
    Assert ((Hash $sourceDll) -ceq $row.sha256) "Published source DLL drift: $($row.path)"
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $targetDll))
    Copy-Item -LiteralPath $sourceDll -Destination $targetDll -Force
    Assert ((Hash $targetDll) -ceq $row.sha256) "Native Linux DLL copy drift: $($row.path)"
}
Assert (-not(Test-Path $WorkRoot)) 'WorkRoot must be absent.'
[void][IO.Directory]::CreateDirectory($WorkRoot)
$BaseInstallRoot=Join-Path $WorkRoot 'base-install';$BaseReceiptPath=Join-Path $WorkRoot 'base-receipt.json'
$installer=Join-Path $TargetRoot 'docs/guards/v4/core/distribution/Install-V4Distribution.ps1'
$installResult=@(& pwsh -NoProfile -File $installer -Mode Install -InstallRoot $BaseInstallRoot -ReceiptPath $BaseReceiptPath -ArchivePath $BaseArchivePath 2>&1) -join "`n"
Assert ($LASTEXITCODE -eq 0 -and ($installResult|ConvertFrom-Json).status -ceq 'pass') "Linux base install failed: $installResult"
$receipt=Get-Content $BaseReceiptPath -Raw|ConvertFrom-Json -Depth 100
$windowsFiles=@($windowsReceipt.files|Sort-Object path|ForEach-Object{"$($_.path)|$($_.sha256)|$($_.size)"}) -join "`n"
$linuxFiles=@($receipt.files|Sort-Object path|ForEach-Object{"$($_.path)|$($_.sha256)|$($_.size)"}) -join "`n"
Assert ($receipt.id -ceq $windowsReceipt.id -and $receipt.version -ceq $windowsReceipt.version -and $receipt.archiveSha256 -ceq $windowsReceipt.archiveSha256 -and $receipt.manifestSha256 -ceq $windowsReceipt.manifestSha256 -and $linuxFiles -ceq $windowsFiles) 'Linux base receipt payload identity differs from published Windows receipt.'
$basePackage=Join-Path $BaseInstallRoot 'package';$baseResult=@(& pwsh -NoProfile -File (Join-Path $basePackage 'core/runtime/Test-V4Package.ps1') -PackageRoot $basePackage) -join "`n"
Assert ($LASTEXITCODE -eq 0 -and ($baseResult|ConvertFrom-Json).status -ceq 'pass') 'Linux base Package invalid.'
$composed=Join-Path $WorkRoot 'composed';$compositionReceipt=Join-Path $WorkRoot 'composition.receipt.json';$state=Join-Path $WorkRoot 'compose-state';$evidence=Join-Path $WorkRoot 'compose-evidence'
[void][IO.Directory]::CreateDirectory($state);[void][IO.Directory]::CreateDirectory($evidence)
$compose=@(& pwsh -NoProfile -File (Join-Path $basePackage 'core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $BaseArchivePath -BundleRoot $BundleRoot -ReviewRecordPath $ReviewRecordPath -OutputInstallRoot $composed -CompositionReceiptPath $compositionReceipt -TargetRoot $TargetRoot -StateRoot $state -EvidenceRoot $evidence -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Linux composition failed: $($compose -join ' ')"
$verify=@(& pwsh -NoProfile -File (Join-Path $basePackage 'core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $compositionReceipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1) -join "`n"
Assert ($LASTEXITCODE -eq 0 -and ($verify|ConvertFrom-Json).status -ceq 'pass') "Linux composition receipt failed: $verify"
$packageBefore=Fingerprint (Join-Path $composed 'package');$trackedBefore=@(& git -C $TargetRoot status --porcelain --untracked-files=no) -join "`n"
$hostEvidence=Join-Path $WorkRoot 'host-evidence';[void][IO.Directory]::CreateDirectory($hostEvidence)
$typeRoot=[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($TypeLockPath))
Copy-Item -LiteralPath (Join-Path $typeRoot 'assembly-manifest.json') -Destination (Join-Path $hostEvidence 'assembly-manifest.json')
Copy-Item -LiteralPath (Join-Path $typeRoot 'assemblies') -Destination (Join-Path $hostEvidence 'assemblies') -Recurse
$cases=[Collections.Generic.List[object]]::new()
foreach($spec in @([ordered]@{id='direct-pre';stage='pre';count=10;claims=22;dependencies=$false},[ordered]@{id='direct-post';stage='post';count=27;claims=57;dependencies=$false},[ordered]@{id='dependency-post';stage='post';count=37;claims=79;dependencies=$true})){
    $hostState=Join-Path $WorkRoot "host-state-$($spec.id)";[void][IO.Directory]::CreateDirectory($hostState)
    $args=@((Join-Path $composed 'host/v4-guards.dll'),'stage','run','--stage',$spec.stage,'--package-root',(Join-Path $composed 'package'),'--target-root',$TargetRoot,'--state-root',$hostState,'--evidence-root',$hostEvidence,'--profile','ifx_profile')
    if($spec.dependencies){$args+='--with-dependencies'}
    $raw=@(& dotnet @args 2>&1) -join "`n"
    try{$result=$raw|ConvertFrom-Json -Depth 100}catch{throw "Non-JSON Linux Host $($spec.id): $raw"}
    if($LASTEXITCODE -ne 0 -or $result.status -cne 'pass' -or @($result.moduleResults).Count -ne $spec.count -or @($result.coverage).Count -ne $spec.claims -or @($result.findings).Count -ne 0){
        WriteJson (Join-Path (Split-Path -Parent $ReportPath) "linux-failure-$($spec.id).json") $result
        throw "Linux Host failed $($spec.id): status=$($result.status), category=$($result.exitCategory), findings=$(@($result.findings|ForEach-Object{$_.subject}) -join '; ')"
    }
    Assert (@($result.coverage|Where-Object{$_.matched -lt $_.minimum}).Count -eq 0) "Vacuous Linux coverage $($spec.id)."
    $expectedStages=if($spec.dependencies){'bootstrap,analysis,pre,post'}else{$spec.stage}
    Assert ((@($result.executedStages) -join ',') -ceq $expectedStages) "Linux stage order drift $($spec.id)."
    $cases.Add([ordered]@{id=$spec.id;status='pass';moduleCount=$spec.count;claimCount=$spec.claims;stages=@($result.executedStages)})
}
$trackedAfter=@(& git -C $TargetRoot status --porcelain --untracked-files=no) -join "`n"
Assert ((Fingerprint (Join-Path $composed 'package')) -ceq $packageBefore -and $trackedAfter -ceq $trackedBefore) 'Linux Package or tracked TargetRoot changed.'
foreach($entry in $windows.locks){Assert ((Hash (Join-Path $TargetRoot $entry.path)) -ceq $entry.sha256) "Evidence lock changed: $($entry.id)"}
WriteJson $ReportPath ([ordered]@{formatVersion=1;status='pass';scope='c6c1-linux-synthetic-candidate';sourceCommit=$commit;baseVersion='1.1.3';bundleManifestSha256=Hash $manifest;profileSha256=Hash $profile;linuxSdk='10.0.303';windowsBaseReceiptSha256=Hash $WindowsBaseReceiptPath;linuxBaseReceiptSha256=Hash $BaseReceiptPath;basePayloadIdentity='equal';cases=@($cases.ToArray());compositionReceiptSha256=Hash $compositionReceipt;windowsSummarySha256=Hash $WindowsSummaryPath;limitations=@('Synthetic review is not Xiaolong Feng approval.','Independent detector-family violation/zero-match matrix remains required.')})
Write-Output "IFX C6c1 Linux candidate passed: $ReportPath"
