[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InventoryPath,
    [Parameter(Mandatory)][string]$BundleRoot,
    [Parameter(Mandatory)][string]$ReviewRecordPath,
    [Parameter(Mandatory)][string]$WindowsCandidateSummaryPath,
    [Parameter(Mandatory)][string]$SecondCandidateSummaryPath,
    [Parameter(Mandatory)][string]$ContractSummaryPath,
    [Parameter(Mandatory)][string]$FocusedSummaryPath,
    [Parameter(Mandatory)][switch]$AuthorizeRecoveredC6c,
    [string]$ReadinessReportPath = 'artifacts/guards/p10-ifx-114/recovery-042/readiness/summary.json',
    [string]$EvidenceRoot = 'artifacts/guards/p10-ifx-114/c6c-recovery-042-full',
    [string]$AttemptMarkerPath = 'artifacts/guards/p10-ifx-114/c6c-recovery-042-attempt.json',
    [string]$DecisionPath = 'artifacts/guards/p10-ifx-114/recovery-042/c6c-decision.json',
    [string]$BaseInstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.4',
    [string]$BaseReceiptPath = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.4.install.json',
    [string]$BaseArchivePath = 'artifacts/guards/p10-ifx-114/base-archive/v4-guards-1.1.4.zip',
    [string]$CandidateVersion = '0.4.2',
    [ValidateRange(1,3600)][int]$MinimumRemainingSeconds = 2700
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }

Assert $AuthorizeRecoveredC6c.IsPresent 'Recovered C6c requires the explicit -AuthorizeRecoveredC6c switch.'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
Assert (-not (Test-Path -LiteralPath (Full $AttemptMarkerPath))) 'Recovered C6c attempt marker already exists; rerun is forbidden.'
Assert (-not (Test-Path -LiteralPath (Full $EvidenceRoot))) 'Recovered C6c EvidenceRoot must be absent.'
Assert (-not (Test-Path -LiteralPath (Full $DecisionPath))) 'Recovered C6c decision path must be absent.'

$readiness = Join-Path $PSScriptRoot 'Test-IFX114C6cReadiness.ps1'
& pwsh -NoLogo -NoProfile -NonInteractive -File $readiness `
    -InventoryPath $InventoryPath `
    -WindowsCandidateSummaryPath $WindowsCandidateSummaryPath `
    -SecondCandidateSummaryPath $SecondCandidateSummaryPath `
    -ContractSummaryPath $ContractSummaryPath `
    -FocusedSummaryPath $FocusedSummaryPath `
    -ReportPath $ReadinessReportPath `
    -CandidateVersion $CandidateVersion `
    -MinimumRemainingSeconds $MinimumRemainingSeconds
Assert ($LASTEXITCODE -eq 0) 'Recovered C6c readiness failed before the attempt marker was written.'

$single = Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c6c24/Invoke-IFX114SingleC6c.ps1'
& pwsh -NoLogo -NoProfile -NonInteractive -File $single `
    -InventoryPath $InventoryPath `
    -BundleRoot $BundleRoot `
    -ReviewRecordPath $ReviewRecordPath `
    -WindowsCandidateSummaryPath $WindowsCandidateSummaryPath `
    -SecondCandidateSummaryPath $SecondCandidateSummaryPath `
    -ContractSummaryPath $ContractSummaryPath `
    -FocusedSummaryPath $FocusedSummaryPath `
    -EvidenceRoot $EvidenceRoot `
    -AttemptMarkerPath $AttemptMarkerPath `
    -DecisionPath $DecisionPath `
    -BaseInstallRoot $BaseInstallRoot `
    -BaseReceiptPath $BaseReceiptPath `
    -BaseArchivePath $BaseArchivePath `
    -CandidateVersion $CandidateVersion
exit $LASTEXITCODE
