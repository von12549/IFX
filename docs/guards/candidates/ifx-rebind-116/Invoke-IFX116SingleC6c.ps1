# IFX I1 (Plan 20260928-v4-ifx-i1-rebind-1-1-6) successor of
# docs/guards/candidates/ifx-rebind-115/Invoke-IFX115SingleC6c.ps1.
# Derived by exact literal substitution for V4 Guards 1.1.6 from von12549/Guard and
# ifx-profile-candidate 0.4.4. The accepted script stays unchanged as historical authority.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InventoryPath,
    [Parameter(Mandatory)][string]$BundleRoot,
    [Parameter(Mandatory)][string]$ReviewRecordPath,
    [Parameter(Mandatory)][string]$WindowsCandidateSummaryPath,
    [Parameter(Mandatory)][string]$SecondCandidateSummaryPath,
    [Parameter(Mandatory)][string]$ContractSummaryPath,
    [Parameter(Mandatory)][string]$FocusedSummaryPath,
    [string]$EvidenceRoot='artifacts/guards/p10-ifx-116/c6c-full',
    [string]$AttemptMarkerPath='artifacts/guards/p10-ifx-116/c6c-attempt.json',
    [string]$DecisionPath='artifacts/guards/p10-ifx-116/c6c-decision.json',
    [string]$BaseInstallRoot='D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6',
    [string]$BaseReceiptPath='D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.6.install.json',
    [string]$BaseArchivePath='artifacts/guards/p10-ifx-116/base-archive/v4-guards-1.1.6.zip',
    [string]$CandidateVersion='0.4.4'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Assert([bool]$Ok,[string]$Message){if(-not $Ok){throw $Message}}
function Full([string]$Path){if([IO.Path]::IsPathFullyQualified($Path)){[IO.Path]::GetFullPath($Path)}else{[IO.Path]::GetFullPath((Join-Path $repo $Path))}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Fingerprint([string]$Root){@((Get-ChildItem -LiteralPath $Root -File -Recurse -Force|Sort-Object FullName|ForEach-Object{"$([IO.Path]::GetRelativePath($Root,$_.FullName).Replace('\','/'))|$(Hash $_.FullName)"}))-join"`n"}
function WriteJson([string]$Path,$Value){[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path));[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 100).Replace("`r`n","`n")+"`n"),[Text.UTF8Encoding]::new($false))}

$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$commit=(& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant();Assert ($LASTEXITCODE-eq0-and$commit-cmatch'^[a-f0-9]{40}$') 'Target commit unavailable.'
$tracked=@(& git -C $repo status --porcelain --untracked-files=no);Assert ($LASTEXITCODE-eq0-and-not$tracked) 'Single C6c requires a clean tracked target.'
$inventoryFull=Full $InventoryPath;$bundleFull=Full $BundleRoot;$reviewFull=Full $ReviewRecordPath;$candidateFull=Full $WindowsCandidateSummaryPath;$secondFull=Full $SecondCandidateSummaryPath;$contractFull=Full $ContractSummaryPath;$focusedFull=Full $FocusedSummaryPath
foreach($path in @($inventoryFull,$bundleFull,$reviewFull,$candidateFull,$secondFull,$contractFull,$focusedFull,$BaseInstallRoot,$BaseReceiptPath,(Full $BaseArchivePath))){Assert (Test-Path -LiteralPath $path) "Required input missing: $path"}
$inventory=Get-Content $inventoryFull -Raw|ConvertFrom-Json -Depth 100;$candidate=Get-Content $candidateFull -Raw|ConvertFrom-Json -Depth 100;$second=Get-Content $secondFull -Raw|ConvertFrom-Json -Depth 100;$contract=Get-Content $contractFull -Raw|ConvertFrom-Json -Depth 100;$focused=Get-Content $focusedFull -Raw|ConvertFrom-Json -Depth 100
Assert ($inventory.status-ceq'pass'-and$inventory.sourceCommit-ceq$commit-and$inventory.baseVersion-ceq'1.1.6'-and@($inventory.modules).Count-eq37) 'Inventory gate failed.'
Assert ($contract.status-ceq'pass'-and$contract.targetCommit-ceq$commit-and$contract.focusedModuleCount-eq0-and$contract.inheritedModuleCount-eq36-and$contract.hostContractRequalifiedCount-eq7) 'Contract/inheritance gate failed.'
Assert ($focused.status-ceq'pass'-and$focused.targetCommit-ceq$commit-and$focused.baseVersion-ceq'1.1.6'-and$focused.bundleVersion-ceq$CandidateVersion-and@($focused.modules).Count-eq7) 'Focused qualification gate failed.'
Assert ($candidate.status-ceq'pass'-and$candidate.hostValidated-and$candidate.sourceCommit-ceq$commit-and$candidate.baseVersion-ceq'1.1.6'-and$candidate.bundleVersion-ceq$CandidateVersion-and$candidate.workspaceEvidenceDeclared) 'Primary candidate gate failed.'
Assert ($second.status-ceq'partial'-and-not$second.hostValidated-and$second.sourceCommit-ceq$commit-and$second.baseVersion-ceq'1.1.6'-and$second.bundleVersion-ceq$CandidateVersion-and$second.workspaceEvidenceDeclared) 'Second composition gate failed.'
foreach($field in @('bundleManifestSha256','profileSha256','ordinalInventorySha256','compositionReceiptProjectionSha256','composedPackageFingerprintSha256')){Assert ([string]$candidate.$field-ceq[string]$second.$field) "Determinism mismatch: $field"}
$bundleManifest=Get-Content (Join-Path $bundleFull 'bundle-manifest.json') -Raw|ConvertFrom-Json -Depth 100;Assert ($bundleManifest.version-ceq$CandidateVersion-and$bundleManifest.baseVersion-ceq'1.1.6'-and(Hash (Join-Path $bundleFull 'bundle-manifest.json'))-ceq$candidate.bundleManifestSha256) 'Frozen bundle identity mismatch.'
Assert ((Hash (Full $BaseArchivePath))-ceq'92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8'-and(Hash $BaseReceiptPath)-ceq'a5c47ac809d3bd29815f94d6f6481ddb59952c0435fc908c9ab3e71e9359e497') 'Frozen 1.1.6 input drift.'
$packageCheck=& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/runtime/Test-V4Package.ps1') -PackageRoot (Join-Path $BaseInstallRoot 'package')|ConvertFrom-Json -Depth 100
Assert ($LASTEXITCODE-eq0-and$packageCheck.status-ceq'pass'-and$packageCheck.packageHash-ceq'a09469f77956190fbffa827ff5b7da2a63b615d66bf47a86ad0d17c7207bc825') 'Frozen 1.1.6 Package drift.'
$attemptFull=Full $AttemptMarkerPath;$decisionFull=Full $DecisionPath;$certificationRoot=Full $EvidenceRoot
Assert (-not(Test-Path -LiteralPath $attemptFull)) 'A full C6c attempt is already recorded; rerun is forbidden.'
Assert (-not(Test-Path -LiteralPath $certificationRoot)) 'C6c EvidenceRoot must be absent.'
$bundleBefore=Fingerprint $bundleFull;$started=[DateTimeOffset]::UtcNow
WriteJson $attemptFull ([ordered]@{formatVersion=1;status='running';scope='single-full-c6c';targetCommit=$commit;startedAt=$started.ToString('o');inventorySha256=Hash $inventoryFull;bundleManifestSha256=Hash (Join-Path $bundleFull 'bundle-manifest.json');focusedSummarySha256=Hash $focusedFull})
$runner=Join-Path $PSScriptRoot 'Invoke-IFX116ParallelCertification.ps1'
$lines=@(& pwsh -NoLogo -NoProfile -NonInteractive -File $runner -InventoryPath $inventoryFull -BundleRoot $bundleFull -ReviewRecordPath $reviewFull -WindowsCandidateSummaryPath $candidateFull -WindowsBaseReceiptPath $BaseReceiptPath -BaseArchivePath (Full $BaseArchivePath) -BaseInstallRoot $BaseInstallRoot -EvidenceRoot $certificationRoot -ExpectedBaseVersion '1.1.6' -ExpectedArchiveSha256 '92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8' -ExpectedPackageHash 'a09469f77956190fbffa827ff5b7da2a63b615d66bf47a86ad0d17c7207bc825' -CandidateVersion $CandidateVersion 2>&1);$code=$LASTEXITCODE
$completed=[DateTimeOffset]::UtcNow;Assert ((Fingerprint $bundleFull)-ceq$bundleBefore) 'Frozen candidate bytes changed during C6c.'
$summaryPath=Join-Path $certificationRoot 'summary.json';$summary=$null;if(Test-Path -LiteralPath $summaryPath){$summary=Get-Content $summaryPath -Raw|ConvertFrom-Json -Depth 100}
$status=if($code-eq0-and$null-ne$summary-and$summary.status-ceq'pass'){'pass'}else{'failed'}
WriteJson $attemptFull ([ordered]@{formatVersion=1;status=$status;scope='single-full-c6c';targetCommit=$commit;startedAt=$started.ToString('o');completedAt=$completed.ToString('o');elapsedSeconds=[math]::Round(($completed-$started).TotalSeconds,3);exitCode=$code;inventorySha256=Hash $inventoryFull;bundleManifestSha256=Hash (Join-Path $bundleFull 'bundle-manifest.json');focusedSummarySha256=Hash $focusedFull;certificationSummarySha256=$(if($null-ne$summary){Hash $summaryPath}else{$null});output=@($lines|ForEach-Object{[string]$_})})
WriteJson $decisionFull ([ordered]@{formatVersion=1;status=$status;decision=$(if($status-ceq'pass'){'phase-1-complete-stop-for-human-review'}else{'phase-1-failed-stop-no-repair-no-rerun'});targetCommit=$commit;baseVersion='1.1.6';candidateVersion=$CandidateVersion;contractSummary=[ordered]@{path=$contractFull;sha256=Hash $contractFull};focusedSummary=[ordered]@{path=$focusedFull;sha256=Hash $focusedFull};inventory=[ordered]@{path=$inventoryFull;sha256=Hash $inventoryFull};candidate=[ordered]@{path=$bundleFull;manifestSha256=Hash (Join-Path $bundleFull 'bundle-manifest.json')};c6c=[ordered]@{attemptMarker=$attemptFull;summaryPath=$summaryPath;exitCode=$code;productCertification=$(if($null-ne$summary){$summary.productCertification}else{$null});portabilityAssessment=$(if($null-ne$summary){$summary.portabilityAssessment}else{$null})};risks=@('The I1 C6d successor human review (S6) is still required.','The synthetic review fixture is not human extension acceptance.','Linux is a visible non-blocking portability assessment under C6c22.');recommendation=$(if($status-ceq'pass'){'Review phase-1 evidence before explicitly authorizing C6d.'}else{'Do not rerun C6c; review the preserved failure evidence and decide a new plan.'})})
if($status-ceq'pass'){Write-Output "Single full C6c passed; phase 1 stopped: $decisionFull";exit 0}
Write-Error "Single full C6c failed; phase 1 stopped without repair or rerun: $decisionFull" -ErrorAction Continue
exit 1
