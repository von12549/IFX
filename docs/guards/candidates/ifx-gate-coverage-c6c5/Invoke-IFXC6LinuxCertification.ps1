[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WindowsSummaryPath,
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$InventoryPath,
    [Parameter(Mandatory)][string]$BundleRoot,
    [Parameter(Mandatory)][string]$ReviewRecordPath,
    [Parameter(Mandatory)][string]$TargetRoot,
    [Parameter(Mandatory)][string]$WindowsBaseReceiptPath,
    [Parameter(Mandatory)][string]$BaseArchivePath,
    [Parameter(Mandatory)][string]$WorkRoot,
    [Parameter(Mandatory)][string]$PositiveReportPath,
    [Parameter(Mandatory)][string]$MatrixReportPath,
    [Parameter(Mandatory)][string]$ReportPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-Json([string]$Path,$Value) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path)))
    [IO.File]::WriteAllText($Path,(($Value | ConvertTo-Json -Depth 100).Replace("`r`n","`n") + "`n"),[Text.UTF8Encoding]::new($false))
}

Assert $IsLinux 'The C6c5 Linux certification entry point must run natively on Linux.'
Assert ((& dotnet --version).Trim() -ceq '10.0.303') 'Pinned Linux SDK 10.0.303 required.'

$source = [IO.Path]::GetFullPath($SourceRoot)
$target = [IO.Path]::GetFullPath($TargetRoot)
$work = [IO.Path]::GetFullPath($WorkRoot)
$positiveReport = [IO.Path]::GetFullPath($PositiveReportPath)
$matrixReport = [IO.Path]::GetFullPath($MatrixReportPath)
$report = [IO.Path]::GetFullPath($ReportPath)
foreach ($path in @($WindowsSummaryPath,$source,$InventoryPath,$BundleRoot,$ReviewRecordPath,$WindowsBaseReceiptPath,$BaseArchivePath)) {
    Assert (Test-Path -LiteralPath $path) "Required Linux certification input is missing: $path"
}
Assert (-not (Test-Path -LiteralPath $target)) 'Native Linux TargetRoot must be absent.'
Assert (-not (Test-Path -LiteralPath $work)) 'Linux WorkRoot must be absent.'
Assert (-not (Test-Path -LiteralPath ([IO.Path]::GetDirectoryName($matrixReport)))) 'Linux matrix report root must be absent.'

$sourceCommit = (& git -C $source rev-parse HEAD).Trim()
Assert ($LASTEXITCODE -eq 0 -and $sourceCommit.Length -eq 40) 'Source commit is unavailable.'
$tracked = @(& git -C $source status --porcelain --untracked-files=no)
Assert ($LASTEXITCODE -eq 0 -and ($tracked -join '').Trim().Length -eq 0) 'Linux source mount has tracked changes.'

$positiveRunner = Join-Path $source 'docs/guards/candidates/ifx-gate-coverage-c6c1/Test-IFXC6DualPlatformCandidate.ps1'
$positiveOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $positiveRunner `
    -WindowsSummaryPath $WindowsSummaryPath -SourceRoot $source -BundleRoot $BundleRoot `
    -ReviewRecordPath $ReviewRecordPath -TargetRoot $target -WindowsBaseReceiptPath $WindowsBaseReceiptPath `
    -BaseArchivePath $BaseArchivePath -WorkRoot $work -ReportPath $positiveReport 2>&1)
Assert ($LASTEXITCODE -eq 0) "Linux same-candidate validation failed: $($positiveOutput -join "`n")"
$positive = Get-Content -LiteralPath $positiveReport -Raw | ConvertFrom-Json -Depth 100
Assert ($positive.status -ceq 'pass' -and $positive.sourceCommit -ceq $sourceCommit -and @($positive.cases).Count -eq 3) 'Linux positive report is invalid.'

$matrixRunner = Join-Path $target 'docs/guards/candidates/ifx-gate-coverage-c6c3/Test-IFXC6IndependentMatrix.ps1'
$baseInstall = Join-Path $work 'base-install'
$baseReceipt = Join-Path $work 'base-receipt.json'
$matrixRoot = [IO.Path]::GetDirectoryName($matrixReport)
$matrixOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $matrixRunner `
    -InventoryPath $InventoryPath -BundleRoot $BundleRoot -ReviewRecordPath $ReviewRecordPath `
    -Platform linux -BaseInstallRoot $baseInstall -BaseReceiptPath $baseReceipt `
    -BaseArchivePath $BaseArchivePath -EvidenceRoot $matrixRoot -ReportPath $matrixReport 2>&1)
Assert ($LASTEXITCODE -eq 0) "Linux independent matrix failed: $($matrixOutput -join "`n")"
$matrix = Get-Content -LiteralPath $matrixReport -Raw | ConvertFrom-Json -Depth 100
Assert ($matrix.status -ceq 'pass' -and $matrix.platform -ceq 'linux' -and $matrix.sourceCommit -ceq $sourceCommit -and
    $matrix.provenCoreCases -eq 191 -and @($matrix.gaps).Count -eq 0) 'Linux independent matrix report is invalid.'

Write-Json $report ([ordered]@{
    formatVersion = 1
    status = 'pass'
    scope = 'c6c5-linux-certification'
    sourceCommit = $sourceCommit
    sdk = '10.0.303'
    networkExpectation = 'disabled-by-orchestrator'
    positiveReportPath = $positiveReport
    positiveReportSha256 = Hash $positiveReport
    matrixReportPath = $matrixReport
    matrixReportSha256 = Hash $matrixReport
    caseManifestPath = [string]$matrix.caseManifestPath
    caseManifestSha256 = [string]$matrix.caseManifestSha256
    provenCoreCases = [int]$matrix.provenCoreCases
    gaps = @($matrix.gaps)
})
Write-Output "IFX C6c5 Linux certification passed: $report"
