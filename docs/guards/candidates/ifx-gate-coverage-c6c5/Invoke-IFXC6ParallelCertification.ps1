[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InventoryPath,
    [Parameter(Mandatory)][string]$BundleRoot,
    [Parameter(Mandatory)][string]$ReviewRecordPath,
    [Parameter(Mandatory)][string]$WindowsCandidateSummaryPath,
    [Parameter(Mandatory)][string]$WindowsBaseReceiptPath,
    [Parameter(Mandatory)][string]$BaseArchivePath,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [string]$BaseInstallRoot = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.3',
    [string]$LinuxImage = 'ifx-c6c-sdk:10.0.303',
    [string]$LinuxImageDigest = 'sha256:7d373379cf99594538947415d2770f0823a39e3c957cf7e81488370561168773',
    [string]$NuGetPackagesRoot = (Join-Path $env:USERPROFILE '.nuget/packages'),
    [string]$ReportPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'IFX.C6.CertificationPolicy.psm1') -Force

function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function File-Evidence([string]$Root,[string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    [ordered]@{path=Relative-Under $Root $Path;sha256=Hash $Path}
}
function Write-Json([string]$Path,$Value) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path)))
    [IO.File]::WriteAllText($Path,(($Value | ConvertTo-Json -Depth 100).Replace("`r`n","`n") + "`n"),[Text.UTF8Encoding]::new($false))
}
function Relative-Under([string]$Root,[string]$Path) {
    $relative = [IO.Path]::GetRelativePath($Root,[IO.Path]::GetFullPath($Path)).Replace('\','/')
    Assert (-not [IO.Path]::IsPathRooted($relative) -and $relative -ne '..' -and -not $relative.StartsWith('../')) "Path must be under SourceRoot: $Path"
    $relative
}
function Start-Captured([string]$Name,[string]$File,[string[]]$Arguments,[string]$Directory,[string]$LogRoot) {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $File
    $info.WorkingDirectory = $Directory
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$info.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $info
    Assert $process.Start() "Failed to start $Name."
    [ordered]@{name=$Name;process=$process;stdout=$process.StandardOutput.ReadToEndAsync();stderr=$process.StandardError.ReadToEndAsync();logRoot=$LogRoot}
}
function Complete-Captured($Entry) {
    $Entry.process.WaitForExit()
    $stdout = $Entry.stdout.GetAwaiter().GetResult(); $stderr = $Entry.stderr.GetAwaiter().GetResult()
    [void][IO.Directory]::CreateDirectory($Entry.logRoot)
    [IO.File]::WriteAllText((Join-Path $Entry.logRoot 'stdout.txt'),$stdout,[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $Entry.logRoot 'stderr.txt'),$stderr,[Text.UTF8Encoding]::new($false))
    $result = [ordered]@{name=$Entry.name;exitCode=$Entry.process.ExitCode;stdoutSha256=Hash (Join-Path $Entry.logRoot 'stdout.txt');stderrSha256=Hash (Join-Path $Entry.logRoot 'stderr.txt')}
    $Entry.process.Dispose(); $result
}
function Semantic-Cases([string]$Path) {
    $document = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -Depth 100
    @($document.cases | Sort-Object id | ForEach-Object {
        [ordered]@{id=[string]$_.id;kind=[string]$_.kind;moduleId=[string]$_.moduleId;ruleId=[string]$_.ruleId;claimIds=@($_.claimIds);expected=$_.expected;actual=$_.actual;status=[string]$_.status}
    }) | ConvertTo-Json -Depth 100 -Compress
}

Assert $IsWindows 'The C6c5 parallel orchestrator must run on Windows.'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$commit = (& git -C $repo rev-parse HEAD).Trim()
Assert ($LASTEXITCODE -eq 0 -and $commit.Length -eq 40) 'Git commit unavailable.'
$tracked = @(& git -C $repo status --porcelain --untracked-files=no)
Assert ($LASTEXITCODE -eq 0 -and ($tracked -join '').Trim().Length -eq 0) 'Tracked source must be clean.'
foreach ($path in @($InventoryPath,$BundleRoot,$ReviewRecordPath,$WindowsCandidateSummaryPath,$WindowsBaseReceiptPath,$BaseArchivePath,$BaseInstallRoot)) {
    Assert (Test-Path -LiteralPath $path) "Required certification input is missing: $path"
}
$root = [IO.Path]::GetFullPath($EvidenceRoot)
Assert (-not (Test-Path -LiteralPath $root)) 'Certification EvidenceRoot must be absent.'
[void][IO.Directory]::CreateDirectory($root)
$report = if ($ReportPath) { [IO.Path]::GetFullPath($ReportPath) } else { Join-Path $root 'summary.json' }

$imageId = ''
$linuxPreflightDiagnostic = $null
try {
    $imageInspect = @(& docker image inspect --format '{{.Id}}' $LinuxImage 2>&1)
    $imageExitCode = $LASTEXITCODE
    $imageId = ($imageInspect -join '').Trim()
    if ($imageExitCode -ne 0) { $linuxPreflightDiagnostic = "Pinned Linux image inspection failed: $($imageInspect -join ' ')" }
    elseif ($imageId -cne $LinuxImageDigest) { $linuxPreflightDiagnostic = "Pinned Linux image digest mismatch: $imageId" }
} catch {
    $linuxPreflightDiagnostic = "Pinned Linux image inspection failed: $($_.Exception.Message)"
}
if (-not (Test-Path -LiteralPath $NuGetPackagesRoot -PathType Container)) {
    $linuxPreflightDiagnostic = "Offline Linux NuGet cache is missing: $NuGetPackagesRoot"
}
$linuxRunnable = [string]::IsNullOrWhiteSpace($linuxPreflightDiagnostic)

$inventoryRelative = Relative-Under $repo $InventoryPath
$bundleRelative = Relative-Under $repo $BundleRoot
$reviewRelative = Relative-Under $repo $ReviewRecordPath
$candidateRelative = Relative-Under $repo $WindowsCandidateSummaryPath
$archiveRelative = Relative-Under $repo $BaseArchivePath
$windowsMatrix = Join-Path $root 'windows/summary.json'
$controls = Join-Path $root 'controls/summary.json'
$linuxSummary = Join-Path $root 'linux/summary.json'
$windowsRunner = Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c6c3/Test-IFXC6IndependentMatrix.ps1'
$controlRunner = Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c6c5/Test-IFXC6CertificationControls.ps1'
$linuxRunner = '/source/docs/guards/candidates/ifx-gate-coverage-c6c5/Invoke-IFXC6LinuxCertification.ps1'

$windowsArgs = @('-NoLogo','-NoProfile','-NonInteractive','-File',$windowsRunner,
    '-InventoryPath',$InventoryPath,'-BundleRoot',$BundleRoot,'-ReviewRecordPath',$ReviewRecordPath,
    '-Platform','windows','-BaseInstallRoot',$BaseInstallRoot,'-BaseReceiptPath',$WindowsBaseReceiptPath,
    '-BaseArchivePath',$BaseArchivePath,'-EvidenceRoot',(Join-Path $root 'windows'),'-ReportPath',$windowsMatrix)
$controlArgs = @('-NoLogo','-NoProfile','-NonInteractive','-File',$controlRunner,
    '-InventoryPath',$InventoryPath,'-BundleRoot',$BundleRoot,'-ReviewRecordPath',$ReviewRecordPath,
    '-BaseInstallRoot',$BaseInstallRoot,'-BaseReceiptPath',$WindowsBaseReceiptPath,'-BaseArchivePath',$BaseArchivePath,
    '-EvidenceRoot',(Join-Path $root 'controls'),'-ReportPath',$controls)
$dockerArgs = @('run','--rm','--network','none',
    '--mount',"type=bind,source=$repo,target=/source,readonly",
    '--mount',"type=bind,source=$root,target=/out",
    '--mount',"type=bind,source=$WindowsBaseReceiptPath,target=/inputs/windows-base-receipt.json,readonly",
    '--mount',"type=bind,source=$NuGetPackagesRoot,target=/root/.nuget/packages,readonly",
    $LinuxImage,'pwsh','-NoLogo','-NoProfile','-NonInteractive','-File',$linuxRunner,
    '-WindowsSummaryPath',"/source/$candidateRelative",'-SourceRoot','/source','-InventoryPath',"/source/$inventoryRelative",
    '-BundleRoot',"/source/$bundleRelative",'-ReviewRecordPath',"/source/$reviewRelative",'-TargetRoot','/out/linux/native-checkout',
    '-WindowsBaseReceiptPath','/inputs/windows-base-receipt.json','-BaseArchivePath',"/source/$archiveRelative",
    '-WorkRoot','/out/linux/work','-PositiveReportPath','/out/linux/positive.json','-MatrixReportPath','/out/linux/matrix/summary.json',
    '-ReportPath','/out/linux/summary.json')

$running = [Collections.Generic.List[object]]::new()
$running.Add((Start-Captured 'windows-matrix' 'pwsh' $windowsArgs $repo (Join-Path $root 'logs/windows')))
$running.Add((Start-Captured 'controls' 'pwsh' $controlArgs $repo (Join-Path $root 'logs/controls')))
if ($linuxRunnable) { $running.Add((Start-Captured 'linux' 'docker' $dockerArgs $repo (Join-Path $root 'logs/linux'))) }
$processList = [Collections.Generic.List[object]]::new()
foreach ($entry in $running) { $processList.Add((Complete-Captured $entry)) }
if (-not $linuxRunnable) {
    $linuxLogRoot = Join-Path $root 'logs/linux'
    [void][IO.Directory]::CreateDirectory($linuxLogRoot)
    [IO.File]::WriteAllText((Join-Path $linuxLogRoot 'stdout.txt'),'',[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $linuxLogRoot 'stderr.txt'),$linuxPreflightDiagnostic,[Text.UTF8Encoding]::new($false))
    $processList.Add([ordered]@{name='linux';exitCode=125;stdoutSha256=Hash (Join-Path $linuxLogRoot 'stdout.txt');stderrSha256=Hash (Join-Path $linuxLogRoot 'stderr.txt')})
}
$processes = @($processList.ToArray())
$processByName = @{}
foreach ($process in $processes) { $processByName[$process.name] = $process }
Assert ($processByName['windows-matrix'].exitCode -eq 0) "Windows product certification failed; see $root/logs/windows."
Assert ($processByName['controls'].exitCode -eq 0) "Certification controls failed; see $root/logs/controls."

foreach ($path in @($windowsMatrix,$controls)) { Assert (Test-Path -LiteralPath $path) "Blocking certification report missing: $path" }
$windows = Get-Content -LiteralPath $windowsMatrix -Raw | ConvertFrom-Json -Depth 100
$control = Get-Content -LiteralPath $controls -Raw | ConvertFrom-Json -Depth 100
Assert ($windows.status -ceq 'pass' -and $windows.platform -ceq 'windows' -and $windows.provenCoreCases -eq 191) 'Windows matrix report invalid.'
Assert ($control.status -ceq 'pass') 'Certification controls report invalid.'
$windowsCases = Join-Path ([IO.Path]::GetDirectoryName($windowsMatrix)) 'case-manifest.json'
$linuxCases = Join-Path $root 'linux/matrix/case-manifest.json'
$linuxMatrix = Join-Path $root 'linux/matrix/summary.json'
Assert (Test-Path -LiteralPath $windowsCases -PathType Leaf) "Windows case manifest missing: $windowsCases"

$linuxDiagnostics = [Collections.Generic.List[string]]::new()
$linuxPreflightDiagnostic | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $linuxDiagnostics.Add($_) }
$linuxPassed = $false
$linuxProvenCoreCases = 0
$semanticProjection = 'not-evaluated'
if ($processByName['linux'].exitCode -ne 0) {
    $linuxDiagnostics.Add("linux process exited $($processByName['linux'].exitCode)")
} elseif (-not (Test-Path -LiteralPath $linuxSummary -PathType Leaf) -or -not (Test-Path -LiteralPath $linuxMatrix -PathType Leaf)) {
    $linuxDiagnostics.Add('Linux process exited successfully but required reports are missing.')
} else {
    try {
        $linux = Get-Content -LiteralPath $linuxSummary -Raw | ConvertFrom-Json -Depth 100
        $linuxProvenCoreCases = [int]$linux.provenCoreCases
        $linuxPassed = $linux.status -ceq 'pass' -and $linuxProvenCoreCases -eq 191
        if (-not $linuxPassed) { $linuxDiagnostics.Add('Linux certification report did not prove 191 passing core cases.') }
    } catch {
        $linuxDiagnostics.Add("Linux certification report is unreadable: $($_.Exception.Message)")
    }
}
if ($linuxPassed -and (Test-Path -LiteralPath $linuxCases -PathType Leaf)) {
    try {
        $semanticProjection = if ((Semantic-Cases $windowsCases) -ceq (Semantic-Cases $linuxCases)) { 'equal' } else { 'different' }
        if ($semanticProjection -ceq 'different') { $linuxDiagnostics.Add('Windows/Linux semantic case projections differ.') }
    } catch {
        $semanticProjection = 'not-evaluated'
        $linuxDiagnostics.Add("Semantic projection comparison failed: $($_.Exception.Message)")
    }
} elseif ($linuxPassed) {
    $linuxDiagnostics.Add('Linux case manifest is missing; semantic projection was not evaluated.')
}

$policy = Resolve-IFXC6CertificationPolicy -WindowsPassed $true -ControlsPassed $true -LinuxPassed $linuxPassed -SemanticProjection $semanticProjection
$linuxFailureEvidence = @(
    Get-ChildItem -LiteralPath (Join-Path $root 'linux') -File -Recurse -Filter 'linux-failure-*.json' -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        ForEach-Object { File-Evidence $root $_.FullName }
)
$portability = [ordered]@{
    platform = $policy.portabilityAssessment.platform
    blocking = $policy.portabilityAssessment.blocking
    status = $policy.portabilityAssessment.status
    semanticProjection = $policy.portabilityAssessment.semanticProjection
    reasonCodes = $policy.portabilityAssessment.reasonCodes
    processExitCode = [int]$processByName['linux'].exitCode
    provenCoreCases = $linuxProvenCoreCases
    diagnostics = @($linuxDiagnostics.ToArray())
    report = File-Evidence $root $linuxSummary
    matrixReport = File-Evidence $root $linuxMatrix
    caseManifest = File-Evidence $root $linuxCases
    failureEvidence = $linuxFailureEvidence
}

Write-Json $report ([ordered]@{
    formatVersion=2; status=$policy.productCertification.status; scope='ifx-windows-product-certification'; sourceCommit=$commit
    productCertification=$policy.productCertification
    portabilityAssessment=$portability
    v4PackageReleaseCertification=$policy.v4PackageReleaseCertification
    execution=[ordered]@{linuxImage=$LinuxImage;linuxImageDigest=$LinuxImageDigest;inspectedLinuxImageDigest=$imageId;network='none'}
    windows=[ordered]@{reportSha256=Hash $windowsMatrix;caseManifestSha256=Hash $windowsCases;provenCoreCases=191}
    controls=[ordered]@{reportSha256=Hash $controls;capabilityVariantCount=[int]$control.capabilityVariantCount;lockControlCount=[int]$control.lockControlCount}
    processes=$processes
})
Write-Output "IFX Windows product certification passed: $report (Linux portability: $($portability.status))"
