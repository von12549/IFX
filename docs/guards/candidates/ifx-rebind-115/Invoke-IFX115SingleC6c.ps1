# V4-TODO-008 T7 (Plan 20260928-v4-todo-008-t7-ifx-consumer-rebinding) successor of
# docs/guards/candidates/ifx-gate-coverage-c6c24/Invoke-IFX114SingleC6c.ps1.
# Derived by exact literal substitution for V4 Guards 1.1.5 from von12549/Guard and
# ifx-profile-candidate 0.4.3. The accepted 1.1.4 script stays unchanged as historical authority.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InventoryPath,
    [Parameter(Mandatory)][string]$BundleRoot,
    [Parameter(Mandatory)][string]$ReviewRecordPath,
    [Parameter(Mandatory)][string]$WindowsCandidateSummaryPath,
    [Parameter(Mandatory)][string]$SecondCandidateSummaryPath,
    [Parameter(Mandatory)][string]$ContractSummaryPath,
    [Parameter(Mandatory)][string]$FocusedSummaryPath,
    [string]$EvidenceRoot='artifacts/guards/p10-ifx-115/c6c-full',
    [string]$AttemptMarkerPath='artifacts/guards/p10-ifx-115/c6c-attempt.json',
    [string]$DecisionPath='artifacts/guards/p10-ifx-115/c6c-decision.json',
    [string]$BaseInstallRoot='D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.5',
    [string]$BaseReceiptPath='D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.5.install.json',
    [string]$BaseArchivePath='artifacts/guards/p10-ifx-115/base-archive/v4-guards-1.1.5.zip',
    [string]$CandidateVersion='0.4.3'
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
Assert ($inventory.status-ceq'pass'-and$inventory.sourceCommit-ceq$commit-and$inventory.baseVersion-ceq'1.1.5'-and@($inventory.modules).Count-eq37) 'Inventory gate failed.'
Assert ($contract.status-ceq'pass'-and$contract.targetCommit-ceq$commit-and$contract.focusedModuleCount-eq0-and$contract.inheritedModuleCount-eq36-and$contract.hostContractRequalifiedCount-eq7) 'Contract/inheritance gate failed.'
Assert ($focused.status-ceq'pass'-and$focused.targetCommit-ceq$commit-and$focused.baseVersion-ceq'1.1.5'-and$focused.bundleVersion-ceq$CandidateVersion-and@($focused.modules).Count-eq7) 'Focused qualification gate failed.'
Assert ($candidate.status-ceq'pass'-and$candidate.hostValidated-and$candidate.sourceCommit-ceq$commit-and$candidate.baseVersion-ceq'1.1.5'-and$candidate.bundleVersion-ceq$CandidateVersion-and$candidate.workspaceEvidenceDeclared) 'Primary candidate gate failed.'
Assert ($second.status-ceq'partial'-and-not$second.hostValidated-and$second.sourceCommit-ceq$commit-and$second.baseVersion-ceq'1.1.5'-and$second.bundleVersion-ceq$CandidateVersion-and$second.workspaceEvidenceDeclared) 'Second composition gate failed.'
foreach($field in @('bundleManifestSha256','profileSha256','ordinalInventorySha256','compositionReceiptProjectionSha256','composedPackageFingerprintSha256')){Assert ([string]$candidate.$field-ceq[string]$second.$field) "Determinism mismatch: $field"}
$bundleManifest=Get-Content (Join-Path $bundleFull 'bundle-manifest.json') -Raw|ConvertFrom-Json -Depth 100;Assert ($bundleManifest.version-ceq$CandidateVersion-and$bundleManifest.baseVersion-ceq'1.1.5'-and(Hash (Join-Path $bundleFull 'bundle-manifest.json'))-ceq$candidate.bundleManifestSha256) 'Frozen bundle identity mismatch.'
Assert ((Hash (Full $BaseArchivePath))-ceq'74c371ebca73186d5ef636669a226960982c5c28b13532bc5972cbcdffee3976'-and(Hash $BaseReceiptPath)-ceq'622f3d0cb8e8fc8ead33444931605bc81e23e9cc3628a84384bb4379bb839b31') 'Frozen 1.1.5 input drift.'
$packageCheck=& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $BaseInstallRoot 'package/core/runtime/Test-V4Package.ps1') -PackageRoot (Join-Path $BaseInstallRoot 'package')|ConvertFrom-Json -Depth 100
Assert ($LASTEXITCODE-eq0-and$packageCheck.status-ceq'pass'-and$packageCheck.packageHash-ceq'e8cd32697709e8ca155b051ddbf731e12b65bad42858eafd92cddb0ee4dbf733') 'Frozen 1.1.5 Package drift.'
$attemptFull=Full $AttemptMarkerPath;$decisionFull=Full $DecisionPath;$certificationRoot=Full $EvidenceRoot
Assert (-not(Test-Path -LiteralPath $attemptFull)) 'A full C6c attempt is already recorded; rerun is forbidden.'
Assert (-not(Test-Path -LiteralPath $certificationRoot)) 'C6c EvidenceRoot must be absent.'
$bundleBefore=Fingerprint $bundleFull;$started=[DateTimeOffset]::UtcNow
WriteJson $attemptFull ([ordered]@{formatVersion=1;status='running';scope='single-full-c6c';targetCommit=$commit;startedAt=$started.ToString('o');inventorySha256=Hash $inventoryFull;bundleManifestSha256=Hash (Join-Path $bundleFull 'bundle-manifest.json');focusedSummarySha256=Hash $focusedFull})
$runner=Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c6c5/Invoke-IFXC6ParallelCertification.ps1'
$lines=@(& pwsh -NoLogo -NoProfile -NonInteractive -File $runner -InventoryPath $inventoryFull -BundleRoot $bundleFull -ReviewRecordPath $reviewFull -WindowsCandidateSummaryPath $candidateFull -WindowsBaseReceiptPath $BaseReceiptPath -BaseArchivePath (Full $BaseArchivePath) -BaseInstallRoot $BaseInstallRoot -EvidenceRoot $certificationRoot -ExpectedBaseVersion '1.1.5' -ExpectedArchiveSha256 '74c371ebca73186d5ef636669a226960982c5c28b13532bc5972cbcdffee3976' -ExpectedPackageHash 'e8cd32697709e8ca155b051ddbf731e12b65bad42858eafd92cddb0ee4dbf733' -CandidateVersion $CandidateVersion 2>&1);$code=$LASTEXITCODE
$completed=[DateTimeOffset]::UtcNow;Assert ((Fingerprint $bundleFull)-ceq$bundleBefore) 'Frozen candidate bytes changed during C6c.'
$summaryPath=Join-Path $certificationRoot 'summary.json';$summary=$null;if(Test-Path -LiteralPath $summaryPath){$summary=Get-Content $summaryPath -Raw|ConvertFrom-Json -Depth 100}
$status=if($code-eq0-and$null-ne$summary-and$summary.status-ceq'pass'){'pass'}else{'failed'}
WriteJson $attemptFull ([ordered]@{formatVersion=1;status=$status;scope='single-full-c6c';targetCommit=$commit;startedAt=$started.ToString('o');completedAt=$completed.ToString('o');elapsedSeconds=[math]::Round(($completed-$started).TotalSeconds,3);exitCode=$code;inventorySha256=Hash $inventoryFull;bundleManifestSha256=Hash (Join-Path $bundleFull 'bundle-manifest.json');focusedSummarySha256=Hash $focusedFull;certificationSummarySha256=$(if($null-ne$summary){Hash $summaryPath}else{$null});output=@($lines|ForEach-Object{[string]$_})})
WriteJson $decisionFull ([ordered]@{formatVersion=1;status=$status;decision=$(if($status-ceq'pass'){'phase-1-complete-stop-for-human-review'}else{'phase-1-failed-stop-no-repair-no-rerun'});targetCommit=$commit;baseVersion='1.1.5';candidateVersion=$CandidateVersion;contractSummary=[ordered]@{path=$contractFull;sha256=Hash $contractFull};focusedSummary=[ordered]@{path=$focusedFull;sha256=Hash $focusedFull};inventory=[ordered]@{path=$inventoryFull;sha256=Hash $inventoryFull};candidate=[ordered]@{path=$bundleFull;manifestSha256=Hash (Join-Path $bundleFull 'bundle-manifest.json')};c6c=[ordered]@{attemptMarker=$attemptFull;summaryPath=$summaryPath;exitCode=$code;productCertification=$(if($null-ne$summary){$summary.productCertification}else{$null});portabilityAssessment=$(if($null-ne$summary){$summary.portabilityAssessment}else{$null})};risks=@('The T7 C6d successor human review (R4) is still required.','The synthetic review fixture is not human extension acceptance.','Linux is a visible non-blocking portability assessment under C6c22.');recommendation=$(if($status-ceq'pass'){'Review phase-1 evidence before explicitly authorizing C6d.'}else{'Do not rerun C6c; review the preserved failure evidence and decide a new plan.'})})
if($status-ceq'pass'){Write-Output "Single full C6c passed; phase 1 stopped: $decisionFull";exit 0}
Write-Error "Single full C6c failed; phase 1 stopped without repair or rerun: $decisionFull" -ErrorAction Continue
exit 1
