# IFX I1 (Plan 20260928-v4-ifx-i1-rebind-1-1-6) successor of
# docs/guards/candidates/ifx-rebind-115/Invoke-IFX115C6c.ps1.
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
    [Parameter(Mandatory)][switch]$AuthorizeI1C6c,
    [string]$ReadinessReportPath = 'artifacts/guards/p10-ifx-116/readiness/summary.json',
    [string]$EvidenceRoot = 'artifacts/guards/p10-ifx-116/c6c-full',
    [string]$AttemptMarkerPath = 'artifacts/guards/p10-ifx-116/c6c-attempt.json',
    [string]$DecisionPath = 'artifacts/guards/p10-ifx-116/c6c-decision.json',
    [string]$BaseInstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6',
    [string]$BaseReceiptPath = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.6.install.json',
    [string]$BaseArchivePath = 'artifacts/guards/p10-ifx-116/base-archive/v4-guards-1.1.6.zip',
    [string]$CandidateVersion = '0.4.4',
    [ValidateRange(1,3600)][int]$MinimumRemainingSeconds = 2700
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }

Assert $AuthorizeI1C6c.IsPresent 'I1 C6c requires the explicit -AuthorizeI1C6c switch.'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
Assert (-not (Test-Path -LiteralPath (Full $AttemptMarkerPath))) 'I1 C6c attempt marker already exists; rerun is forbidden.'
Assert (-not (Test-Path -LiteralPath (Full $EvidenceRoot))) 'I1 C6c EvidenceRoot must be absent.'
Assert (-not (Test-Path -LiteralPath (Full $DecisionPath))) 'I1 C6c decision path must be absent.'

$readiness = Join-Path $PSScriptRoot 'Test-IFX116C6cReadiness.ps1'
& pwsh -NoLogo -NoProfile -NonInteractive -File $readiness `
    -InventoryPath $InventoryPath `
    -WindowsCandidateSummaryPath $WindowsCandidateSummaryPath `
    -SecondCandidateSummaryPath $SecondCandidateSummaryPath `
    -ContractSummaryPath $ContractSummaryPath `
    -FocusedSummaryPath $FocusedSummaryPath `
    -ReportPath $ReadinessReportPath `
    -CandidateVersion $CandidateVersion `
    -MinimumRemainingSeconds $MinimumRemainingSeconds
Assert ($LASTEXITCODE -eq 0) 'I1 C6c readiness failed before the attempt marker was written.'

$single = Join-Path $PSScriptRoot 'Invoke-IFX116SingleC6c.ps1'
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
