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

function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
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
foreach ($path in @($InventoryPath,$BundleRoot,$ReviewRecordPath,$WindowsCandidateSummaryPath,$WindowsBaseReceiptPath,$BaseArchivePath,$BaseInstallRoot,$NuGetPackagesRoot)) {
    Assert (Test-Path -LiteralPath $path) "Required certification input is missing: $path"
}
$root = [IO.Path]::GetFullPath($EvidenceRoot)
Assert (-not (Test-Path -LiteralPath $root)) 'Certification EvidenceRoot must be absent.'
[void][IO.Directory]::CreateDirectory($root)
$report = if ($ReportPath) { [IO.Path]::GetFullPath($ReportPath) } else { Join-Path $root 'summary.json' }

$imageId = (@(& docker image inspect --format '{{.Id}}' $LinuxImage 2>&1) -join '').Trim()
Assert ($LASTEXITCODE -eq 0 -and $imageId -ceq $LinuxImageDigest) "Pinned Linux image digest mismatch: $imageId"

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
$running.Add((Start-Captured 'linux' 'docker' $dockerArgs $repo (Join-Path $root 'logs/linux')))
$processes = @($running | ForEach-Object { Complete-Captured $_ })
foreach ($process in $processes) { Assert ($process.exitCode -eq 0) "Parallel certification process failed: $($process.name); see $root/logs." }

foreach ($path in @($windowsMatrix,$controls,$linuxSummary,(Join-Path $root 'linux/matrix/summary.json'))) { Assert (Test-Path -LiteralPath $path) "Certification report missing: $path" }
$windows = Get-Content -LiteralPath $windowsMatrix -Raw | ConvertFrom-Json -Depth 100
$linux = Get-Content -LiteralPath $linuxSummary -Raw | ConvertFrom-Json -Depth 100
$control = Get-Content -LiteralPath $controls -Raw | ConvertFrom-Json -Depth 100
Assert ($windows.status -ceq 'pass' -and $windows.platform -ceq 'windows' -and $windows.provenCoreCases -eq 191) 'Windows matrix report invalid.'
Assert ($linux.status -ceq 'pass' -and $linux.provenCoreCases -eq 191) 'Linux certification report invalid.'
Assert ($control.status -ceq 'pass') 'Certification controls report invalid.'
$windowsCases = Join-Path ([IO.Path]::GetDirectoryName($windowsMatrix)) 'case-manifest.json'
$linuxCases = Join-Path $root 'linux/matrix/case-manifest.json'
Assert ((Semantic-Cases $windowsCases) -ceq (Semantic-Cases $linuxCases)) 'Windows/Linux semantic case projections differ.'

Write-Json $report ([ordered]@{
    formatVersion=1; status='pass'; scope='c6c5-parallel-certification'; sourceCommit=$commit
    linuxImage=$LinuxImage; linuxImageDigest=$LinuxImageDigest; network='none'
    windows=[ordered]@{reportSha256=Hash $windowsMatrix;caseManifestSha256=Hash $windowsCases;provenCoreCases=191}
    linux=[ordered]@{reportSha256=Hash $linuxSummary;caseManifestSha256=Hash $linuxCases;provenCoreCases=191}
    controls=[ordered]@{reportSha256=Hash $controls;capabilityVariantCount=[int]$control.capabilityVariantCount;lockControlCount=[int]$control.lockControlCount}
    semanticProjection='equal'; processes=$processes
})
Write-Output "IFX C6c5 parallel certification passed: $report"
