# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-6 entry: readiness, then the single
# C6c of ifx_profile 0.5.0; successor of candidates/ifx-rebind-116/Invoke-IFX116C6c.ps1 (unchanged). Ruling R4: the
# C6c runs only after IFX-V4-005 is complete (its Plan status), because the solution producer runs the drain tests.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InventoryPath,
    [Parameter(Mandatory)][string]$BundleRoot,
    [Parameter(Mandatory)][string]$ReviewRecordPath,
    [Parameter(Mandatory)][string]$WindowsCandidateSummaryPath,
    [Parameter(Mandatory)][string]$SecondCandidateSummaryPath,
    [Parameter(Mandatory)][string]$ContractSummaryPath,
    [Parameter(Mandatory)][string]$FocusedSummaryPath,
    [Parameter(Mandatory)][switch]$AuthorizeA38C6c,
    [string]$ReadinessReportPath = 'artifacts/guards/p10-ifx-i2b/a3-052/readiness/summary.json',
    [string]$EvidenceRoot = 'artifacts/guards/p10-ifx-i2b/a3-052/c6c-full',
    [string]$AttemptMarkerPath = 'artifacts/guards/p10-ifx-i2b/a3-052/c6c-attempt.json',
    [string]$DecisionPath = 'artifacts/guards/p10-ifx-i2b/a3-052/c6c-decision.json',
    [string]$BaseInstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6',
    [string]$BaseReceiptPath = 'D:/IFX-Root/guard-runtime/receipts/v4-guards-1.1.6.install.json',
    [string]$BaseArchivePath = 'artifacts/guards/p10-ifx-116/base-archive/v4-guards-1.1.6.zip',
    [string]$CandidateVersion = '0.5.2',
    [string]$DrainFixPlanPath = 'docs/guards/plans/20260930-ifx-v4-005-drain-wait-race.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }

Assert $AuthorizeA38C6c.IsPresent 'The A1-6 C6c requires the explicit -AuthorizeA38C6c switch.'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$drainPlan = Full $DrainFixPlanPath
Assert ([IO.File]::Exists($drainPlan) -and ([IO.File]::ReadAllText($drainPlan) -match '(?m)^Status: `COMPLETE')) 'Ruling R4: IFX-V4-005 must be complete before the C6c.'
Assert (-not (Test-Path -LiteralPath (Full $AttemptMarkerPath))) 'A1-6 C6c attempt marker already exists; rerun is forbidden.'
Assert (-not (Test-Path -LiteralPath (Full $EvidenceRoot))) 'A1-6 C6c EvidenceRoot must be absent.'
Assert (-not (Test-Path -LiteralPath (Full $DecisionPath))) 'A1-6 C6c decision path must be absent.'

$readiness = Join-Path $PSScriptRoot 'Test-IFX050C6cReadiness.ps1'
& pwsh -NoLogo -NoProfile -NonInteractive -File $readiness `
    -InventoryPath $InventoryPath `
    -WindowsCandidateSummaryPath $WindowsCandidateSummaryPath `
    -SecondCandidateSummaryPath $SecondCandidateSummaryPath `
    -ContractSummaryPath $ContractSummaryPath `
    -FocusedSummaryPath $FocusedSummaryPath `
    -ReportPath $ReadinessReportPath `
    -CandidateVersion $CandidateVersion
Assert ($LASTEXITCODE -eq 0) 'A1-6 C6c readiness failed before the attempt marker was written.'

$single = Join-Path $PSScriptRoot 'Invoke-IFX050SingleC6c.ps1'
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
