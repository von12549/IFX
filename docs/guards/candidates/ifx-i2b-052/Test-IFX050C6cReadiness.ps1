# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-4 (used in A1-5): C6c readiness of
# ifx_profile 0.5.0; successor of candidates/ifx-rebind-116/Test-IFX116C6cReadiness.ps1 (unchanged). The identity and
# determinism gates are kept. The 0.4.4 lock gate (seven Profile locks with an hour to spare) has no successor: the
# 0.5.0 candidate binds no lock, and the C6c produces its evidence itself. The I1 C6c records must stay intact.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InventoryPath,
    [Parameter(Mandatory)][string]$WindowsCandidateSummaryPath,
    [Parameter(Mandatory)][string]$SecondCandidateSummaryPath,
    [Parameter(Mandatory)][string]$ContractSummaryPath,
    [Parameter(Mandatory)][string]$FocusedSummaryPath,
    [Parameter(Mandatory)][string]$ReportPath,
    [string]$CandidateVersion = '0.5.1',
    [string]$BaseInstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'IFX050.Tooling.psm1') -Force
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$commit = (& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant()
Assert ($LASTEXITCODE -eq 0 -and $commit -cmatch '^[a-f0-9]{40}$') 'Target commit unavailable.'
$tracked = @(& git -C $repo status --porcelain --untracked-files=no)
Assert ($LASTEXITCODE -eq 0 -and -not $tracked) 'C6c readiness requires a clean tracked target.'
$inventoryFull = Full $InventoryPath; $candidateFull = Full $WindowsCandidateSummaryPath; $secondFull = Full $SecondCandidateSummaryPath; $contractFull = Full $ContractSummaryPath; $focusedFull = Full $FocusedSummaryPath
foreach ($path in @($inventoryFull, $candidateFull, $secondFull, $contractFull, $focusedFull)) { Assert ([IO.File]::Exists($path)) "Readiness input is missing: $path" }
$inventory = Get-Content -LiteralPath $inventoryFull -Raw | ConvertFrom-Json -Depth 100 -DateKind String
$candidate = Get-Content -LiteralPath $candidateFull -Raw | ConvertFrom-Json -Depth 100 -DateKind String
$second = Get-Content -LiteralPath $secondFull -Raw | ConvertFrom-Json -Depth 100 -DateKind String
$contract = Get-Content -LiteralPath $contractFull -Raw | ConvertFrom-Json -Depth 100 -DateKind String
$focused = Get-Content -LiteralPath $focusedFull -Raw | ConvertFrom-Json -Depth 100 -DateKind String

Assert ($inventory.status -ceq 'pass' -and $inventory.scope -ceq 'ifx-050a-source-module-claim-inventory' -and $inventory.sourceCommit -ceq $commit -and $inventory.baseVersion -ceq '1.1.6' -and @($inventory.modules).Count -eq 37) 'Readiness inventory identity failed.'
Assert ($candidate.status -ceq 'pass' -and $candidate.hostValidated -and $candidate.sourceCommit -ceq $commit -and $candidate.baseVersion -ceq '1.1.6' -and $candidate.bundleVersion -ceq $CandidateVersion -and $candidate.evidenceModel -ceq 'staged-by-workflow') 'Readiness primary candidate identity failed.'
Assert ($second.status -ceq 'partial' -and -not $second.hostValidated -and $second.sourceCommit -ceq $commit -and $second.baseVersion -ceq '1.1.6' -and $second.bundleVersion -ceq $CandidateVersion) 'Readiness second candidate identity failed.'
Assert ($contract.status -ceq 'pass' -and $contract.targetCommit -ceq $commit -and $contract.inheritedModuleCount -eq 11 -and $contract.baseInheritedModuleCount -eq 1 -and $contract.requalifiedModuleCount -eq 25 -and @($contract.workspaceConsumers).Count -eq 7) 'Readiness contract summary failed.'
Assert ($focused.status -ceq 'pass' -and $focused.targetCommit -ceq $commit -and $focused.baseVersion -ceq '1.1.6' -and $focused.bundleVersion -ceq $CandidateVersion -and @($focused.modules).Count -eq 7) 'Readiness focused summary failed.'
Assert ([string]$candidate.ordinalInventorySha256 -ceq (Hash $inventoryFull)) 'Primary candidate is not bound to the readiness inventory.'
foreach ($field in @('bundleManifestSha256', 'profileSha256', 'ordinalInventorySha256', 'compositionReceiptProjectionSha256', 'composedPackageFingerprintSha256')) {
    Assert ([string]$candidate.$field -ceq [string]$second.$field) "Candidate determinism mismatch: $field"
}

# The I1 C6c (0.4.4) records are history; nothing in I2-B may rewrite them.
$historical = @(
    [ordered]@{ path = 'artifacts/guards/p10-ifx-116/c6c-attempt.json'; sha256 = '5da180bce8d7e569166ab899e7892183fbc55ccbaee3f38a677555a2f6bb4459' },
    [ordered]@{ path = 'artifacts/guards/p10-ifx-116/c6c-decision.json'; sha256 = '504968ff40e94b65d941b47c156633d09c8e3e09d1e8e4300c7b57acca8cf9bd' },
    [ordered]@{ path = 'artifacts/guards/p10-ifx-116/c6c-full/summary.json'; sha256 = '3427ede969104350626909e10928152032542b3ab813ab3df65122796257ec6a' }
)
foreach ($item in $historical) { $full = Full $item.path; Assert ([IO.File]::Exists($full) -and (Get-IFX050PinSha256 $full) -ceq $item.sha256) "Historical C6c evidence drift: $($item.path)" }

$reportFull = Full $ReportPath
$matrixReport = Join-Path ([IO.Path]::GetDirectoryName($reportFull)) 'matrix-contract.json'
$matrixOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'Test-IFX050MatrixContract.ps1') -RepositoryRoot $repo -BaseInstallRoot $BaseInstallRoot -InventoryPath $inventoryFull -ReportPath $matrixReport 2>&1)
Assert ($LASTEXITCODE -eq 0 -and [IO.File]::Exists($matrixReport)) "Matrix contract readiness failed: $($matrixOutput -join ' ')"
$matrix = Get-Content -LiteralPath $matrixReport -Raw | ConvertFrom-Json -Depth 100
Assert ($matrix.status -ceq 'pass') 'Matrix contract readiness did not pass.'
Write-IFX050Json $reportFull ([ordered]@{
    formatVersion = 1; status = 'pass'; scope = 'ifx-050a-c6c-readiness'; targetCommit = $commit; baseVersion = '1.1.6'; candidateVersion = $CandidateVersion; checkedAt = [DateTimeOffset]::UtcNow.ToString('o')
    inventory = [ordered]@{ path = $inventoryFull; sha256 = Hash $inventoryFull }; primaryCandidate = [ordered]@{ path = $candidateFull; sha256 = Hash $candidateFull }; secondCandidate = [ordered]@{ path = $secondFull; sha256 = Hash $secondFull }
    contractSummary = [ordered]@{ path = $contractFull; sha256 = Hash $contractFull }; focusedSummary = [ordered]@{ path = $focusedFull; sha256 = Hash $focusedFull }
    matrixContract = [ordered]@{ path = $matrixReport; sha256 = Hash $matrixReport; inventoryProjectionSha256 = $matrix.inventoryProjectionSha256 }
    evidence = 'produced-by-the-c6c'; preservedC6cEvidence = $historical; authorization = 'readiness-only-full-c6c-not-authorized' })
Write-Output "IFX 0.5.0-a C6c readiness passed: $reportFull"
