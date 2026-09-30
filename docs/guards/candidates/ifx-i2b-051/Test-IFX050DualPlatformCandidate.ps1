# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-4: the Linux same-candidate
# validation of ifx_profile 0.5.0; successor of candidates/ifx-rebind-116/Test-IFX116DualPlatformCandidate.ps1
# (unchanged). As in I1 the native checkout keeps the exact Windows worktree bytes and the base is installed from the
# hash-verified release archive (IFX-V4-003). The 0.4.4 lock files are replaced by the C6c production snapshot
# (IFX050.Production.psm1), imported into the checkout and staged into the Host EvidenceRoot as the workflow stages it.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WindowsSummaryPath,
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$BundleRoot,
    [Parameter(Mandatory)][string]$ReviewRecordPath,
    [Parameter(Mandatory)][string]$TargetRoot,
    [Parameter(Mandatory)][string]$WindowsBaseReceiptPath,
    [Parameter(Mandatory)][string]$BaseArchivePath,
    [Parameter(Mandatory)][string]$ProductionSnapshotRoot,
    [Parameter(Mandatory)][string]$WorkRoot,
    [Parameter(Mandatory)][string]$ReportPath,
    [string]$ExpectedBaseVersion = '1.1.6',
    [string]$ExpectedArchiveSha256 = '92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8',
    [string]$CandidateVersion = '0.5.1'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../ifx-rebind-116/IFX116.ReleaseInstaller.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../ifx-rebind-116/IFX116.NativeStorage.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'IFX050.Production.psm1') -Force
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function WriteJson([string]$Path, $Value) { [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)); [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false)) }
function Fingerprint([string]$Root) { @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force | Sort-Object FullName | ForEach-Object { "$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)" }) -join "`n" }
Assert ($IsLinux -and ((& dotnet --version).Trim() -ceq '10.0.303')) 'Pinned Linux SDK 10.0.303 required.'
$windows = Get-Content $WindowsSummaryPath -Raw | ConvertFrom-Json -Depth 100
Assert ($windows.status -ceq 'pass' -and $windows.hostValidated -and $windows.baseVersion -ceq $ExpectedBaseVersion -and $windows.bundleVersion -ceq $CandidateVersion -and @($windows.cases).Count -eq 3) 'Windows same-candidate report invalid.'
Assert (-not (Test-Path $TargetRoot)) 'Native Linux TargetRoot must be absent.'
$clone = @(& git clone --no-local --quiet -c core.autocrlf=true $SourceRoot $TargetRoot 2>&1)
Assert ($LASTEXITCODE -eq 0) "Native Linux checkout failed: $($clone -join ' ')"
# Preserve the exact clean Windows worktree bytes. Git checkout EOL conversion
# can otherwise alter source and authority hashes despite the same commit.
$sourceTracked = @(& git -c core.autocrlf=true -c core.filemode=false -C $SourceRoot status --porcelain --untracked-files=no)
Assert ($LASTEXITCODE -eq 0 -and ($sourceTracked -join '').Trim().Length -eq 0) 'Bound Windows source has tracked changes.'
# The bytes are those of the Windows checkout that produced the evidence (production snapshot), not of SourceRoot:
# a long-lived worktree can hold mixed line endings that a fresh checkout writes differently.
$sourceCopy = Copy-IFX050ProductionSource -SnapshotRoot $ProductionSnapshotRoot -TargetRoot $TargetRoot
Assert ([int]$sourceCopy.sourceFileCount -gt 4000) 'Bound Windows file inventory unavailable.'
# Amendment A5 (I1): re-record the index of this throwaway checkout after the byte copy.
$checkoutIndexSync = Sync-IFX116CheckoutIndex -TargetRoot $TargetRoot
foreach ($relativeRoot in @('src', 'tests')) {
    foreach ($dir in @(Get-ChildItem -LiteralPath (Join-Path $SourceRoot $relativeRoot) -Directory -Recurse -Force | Where-Object { $_.FullName -notmatch '[\\/](bin|obj|node_modules|dist|coverage|\.vite)([\\/]|$)' })) {
        [void][IO.Directory]::CreateDirectory((Join-Path $TargetRoot ([IO.Path]::GetRelativePath($SourceRoot, $dir.FullName))))
    }
}
$commit = (& git -C $TargetRoot rev-parse HEAD).Trim(); Assert ($LASTEXITCODE -eq 0 -and $commit -ceq $windows.sourceCommit) 'Linux TargetRoot source commit drift.'
$imported = Import-IFX050Production -SnapshotRoot $ProductionSnapshotRoot -TargetRoot $TargetRoot
$productionRecord = [string]$imported.productionRecord
$manifest = Join-Path $BundleRoot 'bundle-manifest.json'; $profile = Join-Path $BundleRoot 'package/profiles/catalog/ifx_profile/profile.json'
Assert ((Hash $manifest) -ceq $windows.bundleManifestSha256 -and (Hash $profile) -ceq $windows.profileSha256) 'Bundle manifest or Profile differs from Windows candidate.'
Assert ((Hash $BaseArchivePath) -ceq $ExpectedArchiveSha256) 'Published base archive drift.'
$windowsReceipt = Get-Content $WindowsBaseReceiptPath -Raw | ConvertFrom-Json -Depth 100
Assert ($windowsReceipt.version -ceq $ExpectedBaseVersion -and $windowsReceipt.archiveSha256 -ceq (Hash $BaseArchivePath)) 'Published Windows base receipt drift.'
$review = Get-Content $ReviewRecordPath -Raw | ConvertFrom-Json -Depth 100
Assert ($review.scope -ceq 'synthetic-test-only' -and $review.bundleManifestSha256 -ceq (Hash $manifest) -and $review.baseArchiveSha256 -ceq (Hash $BaseArchivePath) -and -not $review.acceptedBy.candidateHostVerdictAllowed) 'Synthetic review record mismatch.'
Assert (-not (Test-Path $WorkRoot)) 'WorkRoot must be absent.'
[void][IO.Directory]::CreateDirectory($WorkRoot)
$BaseInstallRoot = Join-Path $WorkRoot 'base-install'; $BaseReceiptPath = Join-Path $WorkRoot 'base-receipt.json'
# IFX-V4-003: the installer comes from the hash-verified release archive, never from the Target.
$releaseInstaller = Get-IFX116ReleaseInstaller -ArchivePath $BaseArchivePath -ExpectedArchiveSha256 $ExpectedArchiveSha256 -Version $ExpectedBaseVersion -WorkRoot $WorkRoot -TargetRoot $TargetRoot
$installResult = @(& pwsh -NoProfile -File $releaseInstaller.installerPath -Mode Install -InstallRoot $BaseInstallRoot -ReceiptPath $BaseReceiptPath -ArchivePath $BaseArchivePath 2>&1) -join "`n"
Assert ($LASTEXITCODE -eq 0 -and ($installResult | ConvertFrom-Json).status -ceq 'pass') "Linux base install failed: $installResult"
$receipt = Get-Content $BaseReceiptPath -Raw | ConvertFrom-Json -Depth 100
$windowsFiles = @($windowsReceipt.files | Sort-Object path | ForEach-Object { "$($_.path)|$($_.sha256)|$($_.size)" }) -join "`n"
$linuxFiles = @($receipt.files | Sort-Object path | ForEach-Object { "$($_.path)|$($_.sha256)|$($_.size)" }) -join "`n"
Assert ($receipt.id -ceq $windowsReceipt.id -and $receipt.version -ceq $windowsReceipt.version -and $receipt.archiveSha256 -ceq $windowsReceipt.archiveSha256 -and $receipt.manifestSha256 -ceq $windowsReceipt.manifestSha256 -and $linuxFiles -ceq $windowsFiles) 'Linux base receipt payload identity differs from published Windows receipt.'
$basePackage = Join-Path $BaseInstallRoot 'package'; $baseResult = @(& pwsh -NoProfile -File (Join-Path $basePackage 'core/runtime/Test-V4Package.ps1') -PackageRoot $basePackage) -join "`n"
Assert ($LASTEXITCODE -eq 0 -and ($baseResult | ConvertFrom-Json).status -ceq 'pass') 'Linux base Package invalid.'
$composed = Join-Path $WorkRoot 'composed'; $compositionReceipt = Join-Path $WorkRoot 'composition.receipt.json'; $state = Join-Path $WorkRoot 'compose-state'; $evidence = Join-Path $WorkRoot 'compose-evidence'
[void][IO.Directory]::CreateDirectory($state); [void][IO.Directory]::CreateDirectory($evidence)
$compose = @(& pwsh -NoProfile -File (Join-Path $basePackage 'core/distribution/Compose-V4Extension.ps1') -BaseInstallRoot $BaseInstallRoot -BaseReceiptPath $BaseReceiptPath -BaseArchivePath $BaseArchivePath -BundleRoot $BundleRoot -ReviewRecordPath $ReviewRecordPath -OutputInstallRoot $composed -CompositionReceiptPath $compositionReceipt -TargetRoot $TargetRoot -StateRoot $state -EvidenceRoot $evidence -AllowSyntheticFixture 2>&1)
Assert ($LASTEXITCODE -eq 0) "Linux composition failed: $($compose -join ' ')"
$verify = @(& pwsh -NoProfile -File (Join-Path $basePackage 'core/distribution/Test-V4ComposedInstallation.ps1') -InstallRoot $composed -ReceiptPath $compositionReceipt -BaseReceiptPath $BaseReceiptPath -AllowSyntheticFixture 2>&1) -join "`n"
Assert ($LASTEXITCODE -eq 0 -and ($verify | ConvertFrom-Json).status -ceq 'pass') "Linux composition receipt failed: $verify"
$packageBefore = Fingerprint (Join-Path $composed 'package'); $trackedBefore = @(& git -C $TargetRoot status --porcelain --untracked-files=no) -join "`n"
# The staged EvidenceRoot, as the trusted-base workflow prepares it before stage run --stage post.
$hostEvidence = Join-Path $WorkRoot 'host-evidence'
$staged = @(& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Invoke-IFX050EvidenceProducers.ps1') -Phase Stage -TargetRoot $TargetRoot -RunRecordPath $productionRecord -EvidenceRoot $hostEvidence 2>&1)
Assert ($LASTEXITCODE -eq 0) "Linux evidence staging failed: $($staged -join ' ')"
$cases = [Collections.Generic.List[object]]::new()
foreach ($spec in @([ordered]@{ id = 'direct-pre'; stage = 'pre'; count = 10; claims = 22; dependencies = $false }, [ordered]@{ id = 'direct-post'; stage = 'post'; count = 27; claims = 57; dependencies = $false }, [ordered]@{ id = 'dependency-post'; stage = 'post'; count = 37; claims = 79; dependencies = $true })) {
    $hostState = Join-Path $WorkRoot "host-state-$($spec.id)"; [void][IO.Directory]::CreateDirectory($hostState)
    $hostArgs = @((Join-Path $composed 'host/v4-guards.dll'), 'stage', 'run', '--stage', $spec.stage, '--package-root', (Join-Path $composed 'package'), '--target-root', $TargetRoot, '--state-root', $hostState, '--evidence-root', $hostEvidence, '--profile', 'ifx_profile')
    if ($spec.dependencies) { $hostArgs += '--with-dependencies' }
    $raw = @(& dotnet @hostArgs 2>&1) -join "`n"; $exit = $LASTEXITCODE
    try { $result = $raw | ConvertFrom-Json -Depth 100 } catch { throw "Non-JSON Linux Host $($spec.id): $raw" }
    if ($exit -ne 0 -or $result.status -cne 'pass' -or @($result.moduleResults).Count -ne $spec.count -or @($result.coverage).Count -ne $spec.claims -or @($result.findings).Count -ne 0) {
        WriteJson (Join-Path (Split-Path -Parent $ReportPath) "linux-failure-$($spec.id).json") $result
        throw "Linux Host failed $($spec.id): status=$($result.status), category=$($result.exitCategory), findings=$(@($result.findings | ForEach-Object { $_.subject }) -join '; ')"
    }
    Assert (@($result.coverage | Where-Object { $_.matched -lt $_.minimum }).Count -eq 0) "Vacuous Linux coverage $($spec.id)."
    $expectedStages = if ($spec.dependencies) { 'bootstrap,analysis,pre,post' } else { $spec.stage }
    Assert ((@($result.executedStages) -join ',') -ceq $expectedStages) "Linux stage order drift $($spec.id)."
    $cases.Add([ordered]@{ id = $spec.id; status = 'pass'; moduleCount = $spec.count; claimCount = $spec.claims; stages = @($result.executedStages) })
}
$trackedAfter = @(& git -C $TargetRoot status --porcelain --untracked-files=no) -join "`n"
Assert ((Fingerprint (Join-Path $composed 'package')) -ceq $packageBefore -and $trackedAfter -ceq $trackedBefore) 'Linux Package or tracked TargetRoot changed.'
WriteJson $ReportPath ([ordered]@{ formatVersion = 1; status = 'pass'; scope = 'ifx-050a-c6c-linux-synthetic-candidate'; sourceCommit = $commit; baseVersion = $ExpectedBaseVersion; bundleVersion = $CandidateVersion; bundleManifestSha256 = Hash $manifest; profileSha256 = Hash $profile
    linuxSdk = '10.0.303'; installerSource = 'release-archive'; installerSha256 = $releaseInstaller.installerSha256; checkoutIndexSync = $checkoutIndexSync; productionSnapshot = $imported; windowsBaseReceiptSha256 = Hash $WindowsBaseReceiptPath; linuxBaseReceiptSha256 = Hash $BaseReceiptPath
    basePayloadIdentity = 'equal'; cases = @($cases.ToArray()); compositionReceiptSha256 = Hash $compositionReceipt; windowsSummarySha256 = Hash $WindowsSummaryPath; limitations = @('Synthetic review is not Xiaolong Feng approval.', 'Independent detector-family violation/zero-match matrix remains required.') })
Write-Output "IFX 0.5.0-a Linux candidate passed: $ReportPath"
