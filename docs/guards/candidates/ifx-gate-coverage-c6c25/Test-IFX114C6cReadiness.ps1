[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InventoryPath,
    [Parameter(Mandatory)][string]$WindowsCandidateSummaryPath,
    [Parameter(Mandatory)][string]$SecondCandidateSummaryPath,
    [Parameter(Mandatory)][string]$ContractSummaryPath,
    [Parameter(Mandatory)][string]$FocusedSummaryPath,
    [Parameter(Mandatory)][string]$ReportPath,
    [string]$CandidateVersion = '0.4.2',
    [ValidateRange(1,3600)][int]$MinimumRemainingSeconds = 2700
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'IFX.C6c25.Readiness.psm1') -Force

function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-Json([string]$Path,$Value) { [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)); [IO.File]::WriteAllText($Path,(($Value | ConvertTo-Json -Depth 100).Replace("`r`n","`n") + "`n"),[Text.UTF8Encoding]::new($false)) }

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$commit = (& git -C $repo rev-parse HEAD).Trim().ToLowerInvariant()
Assert ($LASTEXITCODE -eq 0 -and $commit -cmatch '^[a-f0-9]{40}$') 'Target commit unavailable.'
$tracked = @(& git -C $repo status --porcelain --untracked-files=no)
Assert ($LASTEXITCODE -eq 0 -and -not $tracked) 'C6c readiness requires a clean tracked target.'

$inventoryFull = Full $InventoryPath
$candidateFull = Full $WindowsCandidateSummaryPath
$secondFull = Full $SecondCandidateSummaryPath
$contractFull = Full $ContractSummaryPath
$focusedFull = Full $FocusedSummaryPath
foreach ($path in @($inventoryFull,$candidateFull,$secondFull,$contractFull,$focusedFull)) { Assert ([IO.File]::Exists($path)) "Readiness input is missing: $path" }

$inventory = Get-Content -LiteralPath $inventoryFull -Raw | ConvertFrom-Json -Depth 100 -DateKind String
$candidate = Get-Content -LiteralPath $candidateFull -Raw | ConvertFrom-Json -Depth 100 -DateKind String
$second = Get-Content -LiteralPath $secondFull -Raw | ConvertFrom-Json -Depth 100 -DateKind String
$contract = Get-Content -LiteralPath $contractFull -Raw | ConvertFrom-Json -Depth 100 -DateKind String
$focused = Get-Content -LiteralPath $focusedFull -Raw | ConvertFrom-Json -Depth 100 -DateKind String

Assert ($inventory.status -ceq 'pass' -and $inventory.sourceCommit -ceq $commit -and $inventory.baseVersion -ceq '1.1.4' -and @($inventory.modules).Count -eq 37) 'Readiness inventory identity failed.'
Assert ($candidate.status -ceq 'pass' -and $candidate.hostValidated -and $candidate.sourceCommit -ceq $commit -and $candidate.baseVersion -ceq '1.1.4' -and $candidate.bundleVersion -ceq $CandidateVersion) 'Readiness primary candidate identity failed.'
Assert ($second.status -ceq 'partial' -and -not $second.hostValidated -and $second.sourceCommit -ceq $commit -and $second.baseVersion -ceq '1.1.4' -and $second.bundleVersion -ceq $CandidateVersion) 'Readiness second candidate identity failed.'
Assert ($contract.status -ceq 'pass' -and $contract.targetCommit -ceq $commit -and $contract.focusedModuleCount -eq 7 -and $contract.inheritedModuleCount -eq 29) 'Readiness contract summary failed.'
Assert ($focused.status -ceq 'pass' -and $focused.targetCommit -ceq $commit -and $focused.baseVersion -ceq '1.1.4' -and $focused.bundleVersion -ceq $CandidateVersion -and @($focused.modules).Count -eq 7) 'Readiness focused summary failed.'
Assert ([string]$candidate.ordinalInventorySha256 -ceq (Hash $inventoryFull)) 'Primary candidate is not bound to the readiness inventory.'
foreach ($field in @('bundleManifestSha256','profileSha256','ordinalInventorySha256','compositionReceiptProjectionSha256','composedPackageFingerprintSha256')) {
    Assert ([string]$candidate.$field -ceq [string]$second.$field) "Candidate determinism mismatch: $field"
}

$expectedLockIds = @('assembly','database','frontend','generated','graph','solution','type')
$now = [DateTimeOffset]::UtcNow
$lockRows = @(Assert-IFX114EvidenceLocks -RepositoryRoot $repo -Locks @($candidate.locks) -ExpectedIds $expectedLockIds -TargetCommit $commit -Now $now -MinimumRemainingSeconds $MinimumRemainingSeconds)
$secondLocks = @($second.locks | Sort-Object id | ForEach-Object { "$($_.id)|$($_.path)|$($_.sha256)" })
$primaryLocks = @($candidate.locks | Sort-Object id | ForEach-Object { "$($_.id)|$($_.path)|$($_.sha256)" })
Assert (($primaryLocks -join "`n") -ceq ($secondLocks -join "`n")) 'Candidate evidence-lock selections are nondeterministic.'

$historical = @(
    [ordered]@{path='artifacts/guards/p10-ifx-114/c6c-attempt.json';sha256='23e638d13e7555228dc9712fc9f8877cd6d9ac18a31ebbc0c1ef65b3b167c4b5'},
    [ordered]@{path='artifacts/guards/p10-ifx-114/recovery-041-final2/c6c-decision.json';sha256='2c76990c1cc34278aabd82be94f0af490fcfa788fb1f640c9573da6c435ce02a'},
    [ordered]@{path='artifacts/guards/p10-ifx-114/recovery-041-final2/c6c-result-record.json';sha256='dde33f88ce4c974640f3d0c1a2a025e136d862f5138b3571e7726e18779c6034'}
)
foreach ($item in $historical) { $full = Full $item.path; Assert ([IO.File]::Exists($full) -and (Hash $full) -ceq $item.sha256) "Historical C6c evidence drift: $($item.path)" }

$reportFull = Full $ReportPath
$matrixReport = Join-Path ([IO.Path]::GetDirectoryName($reportFull)) 'matrix-contract.json'
$matrixRunner = Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c6c4/Test-IFXC6MatrixContract.ps1'
$matrixOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $matrixRunner -RepositoryRoot $repo -InventoryPath $inventoryFull -ReportPath $matrixReport 2>&1)
$matrixExit = $LASTEXITCODE
Assert ($matrixExit -eq 0 -and [IO.File]::Exists($matrixReport)) "C6c4 matrix readiness failed: $($matrixOutput -join ' ')"
$matrix = Get-Content -LiteralPath $matrixReport -Raw | ConvertFrom-Json -Depth 100 -DateKind String
Assert ($matrix.status -ceq 'pass') 'C6c4 matrix readiness did not pass.'

$report = [ordered]@{
    formatVersion = 1
    status = 'pass'
    scope = 'ifx-114-c6c-recovery-readiness'
    targetCommit = $commit
    baseVersion = '1.1.4'
    candidateVersion = $CandidateVersion
    checkedAt = $now.ToString('o')
    minimumRemainingSeconds = $MinimumRemainingSeconds
    inventory = [ordered]@{path=$inventoryFull;sha256=Hash $inventoryFull}
    primaryCandidate = [ordered]@{path=$candidateFull;sha256=Hash $candidateFull}
    secondCandidate = [ordered]@{path=$secondFull;sha256=Hash $secondFull}
    contractSummary = [ordered]@{path=$contractFull;sha256=Hash $contractFull}
    focusedSummary = [ordered]@{path=$focusedFull;sha256=Hash $focusedFull}
    matrixContract = [ordered]@{path=$matrixReport;sha256=Hash $matrixReport;inventoryProjectionSha256=$matrix.inventoryProjectionSha256}
    locks = $lockRows
    preservedFailureEvidence = $historical
    authorization = 'readiness-only-full-c6c-not-authorized'
}
Write-Json $reportFull $report
Write-Output "IFX 1.1.4 recovered C6c readiness passed: $reportFull"
