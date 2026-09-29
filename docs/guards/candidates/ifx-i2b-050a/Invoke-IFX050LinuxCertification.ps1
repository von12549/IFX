# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-4: the Linux leg of the ifx_profile
# 0.5.0 C6c; successor of candidates/ifx-rebind-116/Invoke-IFX116LinuxCertification.ps1 (unchanged). Every working
# path stays on container-native storage (IFX-V4-002). The same-candidate validation and the independent matrix run
# on one native checkout that holds the Windows C6c production (snapshot import); the matrix edits and restores it.
# The results come back as one archive (IFXI2B.NativeArchive.psm1, IFX-V4-006) instead of a per-file copy.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$WindowsSummaryPath,
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$InventoryPath,
    [Parameter(Mandatory)][string]$BundleRoot,
    [Parameter(Mandatory)][string]$ReviewRecordPath,
    [Parameter(Mandatory)][string]$ProductionSnapshotRoot,
    [Parameter(Mandatory)][string]$TargetRoot,
    [Parameter(Mandatory)][string]$WindowsBaseReceiptPath,
    [Parameter(Mandatory)][string]$BaseArchivePath,
    [Parameter(Mandatory)][string]$WorkRoot,
    [Parameter(Mandatory)][string]$PositiveReportPath,
    [Parameter(Mandatory)][string]$MatrixReportPath,
    [Parameter(Mandatory)][string]$ReportPath,
    [Parameter(Mandatory)][string]$OutRoot,
    [string]$ExpectedBaseVersion = '1.1.6',
    [string]$ExpectedArchiveSha256 = '92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8',
    [string]$ExpectedPackageHash = 'a09469f77956190fbffa827ff5b7da2a63b615d66bf47a86ad0d17c7207bc825',
    [string]$CandidateVersion = '0.5.0'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-Json([string]$Path, $Value) { [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))); [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false)) }

Assert $IsLinux 'The 0.5.0-a Linux certification entry point must run natively on Linux.'
Import-Module (Join-Path $PSScriptRoot '../ifx-rebind-116/IFX116.NativeStorage.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../ifx-i2b/IFXI2B.NativeArchive.psm1') -Force
# IFX-V4-002: every Linux working path is on container-native storage, never on the bind-mounted roots.
$nativeRoot = Assert-IFX116NativeStorage -Paths @($TargetRoot, $WorkRoot, $PositiveReportPath, $MatrixReportPath, $ReportPath) -BindRoots @($OutRoot, $SourceRoot)
Assert ((& dotnet --version).Trim() -ceq '10.0.303') 'Pinned Linux SDK 10.0.303 required.'
$source = [IO.Path]::GetFullPath($SourceRoot); $target = [IO.Path]::GetFullPath($TargetRoot); $work = [IO.Path]::GetFullPath($WorkRoot)
$positiveReport = [IO.Path]::GetFullPath($PositiveReportPath); $matrixReport = [IO.Path]::GetFullPath($MatrixReportPath); $report = [IO.Path]::GetFullPath($ReportPath)
foreach ($path in @($WindowsSummaryPath, $source, $InventoryPath, $BundleRoot, $ReviewRecordPath, $ProductionSnapshotRoot, $WindowsBaseReceiptPath, $BaseArchivePath)) { Assert (Test-Path -LiteralPath $path) "Required Linux certification input is missing: $path" }
Assert (-not (Test-Path -LiteralPath $target)) 'Native Linux TargetRoot must be absent.'
Assert (-not (Test-Path -LiteralPath $work)) 'Linux WorkRoot must be absent.'
Assert (-not (Test-Path -LiteralPath ([IO.Path]::GetDirectoryName($matrixReport)))) 'Linux matrix report root must be absent.'
$sourceCommit = (& git -C $source rev-parse HEAD).Trim(); Assert ($LASTEXITCODE -eq 0 -and $sourceCommit.Length -eq 40) 'Source commit is unavailable.'
$tracked = @(& git -c core.autocrlf=true -c core.filemode=false -C $source status --porcelain --untracked-files=no)
Assert ($LASTEXITCODE -eq 0 -and ($tracked -join '').Trim().Length -eq 0) 'Linux source mount has tracked changes.'

try {
    $positiveRunner = Join-Path $source 'docs/guards/candidates/ifx-i2b-050a/Test-IFX050DualPlatformCandidate.ps1'
    $positiveOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $positiveRunner `
        -WindowsSummaryPath $WindowsSummaryPath -SourceRoot $source -BundleRoot $BundleRoot -ReviewRecordPath $ReviewRecordPath -TargetRoot $target `
        -WindowsBaseReceiptPath $WindowsBaseReceiptPath -BaseArchivePath $BaseArchivePath -ProductionSnapshotRoot $ProductionSnapshotRoot -WorkRoot $work -ReportPath $positiveReport `
        -ExpectedBaseVersion $ExpectedBaseVersion -ExpectedArchiveSha256 $ExpectedArchiveSha256 -CandidateVersion $CandidateVersion 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Linux same-candidate validation failed: $($positiveOutput -join "`n")"
    $positive = Get-Content -LiteralPath $positiveReport -Raw | ConvertFrom-Json -Depth 100
    Assert ($positive.status -ceq 'pass' -and $positive.sourceCommit -ceq $sourceCommit -and @($positive.cases).Count -eq 3) 'Linux positive report is invalid.'

    # The matrix runs from the native checkout, on it, with the production the positive run imported.
    $matrixRunner = Join-Path $target 'docs/guards/candidates/ifx-i2b-050a/Test-IFX050IndependentMatrix.ps1'
    $matrixOutput = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $matrixRunner `
        -InventoryPath $InventoryPath -BundleRoot $BundleRoot -ReviewRecordPath $ReviewRecordPath -Platform linux `
        -TargetRoot $target -ProductionRecord (Join-Path $ProductionSnapshotRoot 'production.json') `
        -BaseInstallRoot (Join-Path $work 'base-install') -BaseReceiptPath (Join-Path $work 'base-receipt.json') -BaseArchivePath $BaseArchivePath `
        -EvidenceRoot ([IO.Path]::GetDirectoryName($matrixReport)) -ReportPath $matrixReport `
        -ExpectedBaseVersion $ExpectedBaseVersion -ExpectedArchiveSha256 $ExpectedArchiveSha256 -ExpectedPackageHash $ExpectedPackageHash -CandidateVersion $CandidateVersion 2>&1)
    Assert ($LASTEXITCODE -eq 0) "Linux independent matrix failed: $($matrixOutput -join "`n")"
    $matrix = Get-Content -LiteralPath $matrixReport -Raw | ConvertFrom-Json -Depth 100
    Assert ($matrix.status -ceq 'pass' -and $matrix.platform -ceq 'linux' -and $matrix.sourceCommit -ceq $sourceCommit -and $matrix.provenCoreCases -eq 191 -and @($matrix.gaps).Count -eq 0) 'Linux independent matrix report is invalid.'
    Write-Json $report ([ordered]@{ formatVersion = 1; status = 'pass'; scope = 'ifx-050a-linux-certification'; storage = 'container-native'; nativeRoot = $nativeRoot; sourceCommit = $sourceCommit; sdk = '10.0.303'; networkExpectation = 'disabled-by-orchestrator'
        positiveReportPath = $positiveReport; positiveReportSha256 = Hash $positiveReport; matrixReportPath = $matrixReport; matrixReportSha256 = Hash $matrixReport
        caseManifestPath = [string]$matrix.caseManifestPath; caseManifestSha256 = [string]$matrix.caseManifestSha256; provenCoreCases = [int]$matrix.provenCoreCases; gaps = @($matrix.gaps) })
    Write-Output "IFX 0.5.0-a Linux certification passed: $report"
} finally {
    # IFX-V4-006: one archive of the native results (the checkout excluded), plus the reports the runner reads.
    Copy-IFXI2BNativeResults -NativeRoot $nativeRoot -OutRoot $OutRoot -Exclude @([IO.Path]::GetFileName($target))
}
