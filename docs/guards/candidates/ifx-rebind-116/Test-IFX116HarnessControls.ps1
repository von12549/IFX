# IFX I1 (Plan 20260928-v4-ifx-i1-rebind-1-1-6) step S4: negative controls for the C6c Linux harness
# successors. IFX-V4-003: the installer comes only from the hash-verified release archive. IFX-V4-002: every
# Linux working path is on container-native storage. Runs on Windows; the storage controls run in the
# pinned Linux image with the network disabled.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [string]$BaseArchivePath = 'D:/IFX-Root/guard-runtime/downloads/v4-guards-1.1.6/v4-guards-1.1.6.zip',
    [string]$ExpectedArchiveSha256 = '92f1ec54db83de24c9d2096c8da5831b0a50bba0d53b9a4c719ad741f1b392c8',
    [string]$LinuxImage = 'ifx-c6c-sdk:10.0.303',
    [string]$LinuxImageDigest = 'sha256:7d373379cf99594538947415d2770f0823a39e3c957cf7e81488370561168773'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'IFX116.ReleaseInstaller.psm1') -Force
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$root = [IO.Path]::GetFullPath($EvidenceRoot)
if (Test-Path -LiteralPath $root) { throw "EvidenceRoot must be absent: $root" }
[void][IO.Directory]::CreateDirectory($root)
$cases = [Collections.Generic.List[object]]::new()
function Case([string]$Id, [bool]$ExpectReject, [scriptblock]$Body) {
    $message = $null; $rejected = $false; $detail = $null
    try { $detail = & $Body } catch { $rejected = $true; $message = $_.Exception.Message }
    $cases.Add([ordered]@{ id = $Id; expected = $(if ($ExpectReject) { 'reject' } else { 'accept' }); actual = $(if ($rejected) { 'reject' } else { 'accept' }); message = $message; detail = $detail; pass = ($rejected -eq $ExpectReject) })
}

# IFX-V4-003 static control: no I1 harness file names the removed incubation path; the accepted c6c1 script
# does (so the scan is not vacuous). The pattern is assembled so this file does not match itself.
$old = 'docs/guards/' + 'v4/'
Case 'no-harness-file-uses-docs-guards-v4' $false {
    $hits = @(Get-ChildItem -LiteralPath $PSScriptRoot -File | Where-Object { (Get-Content -LiteralPath $_.FullName -Raw).Contains($old) } | ForEach-Object Name)
    if ($hits.Count -ne 0) { throw "Harness files reference the removed path: $($hits -join ', ')" }
    $accepted = Join-Path $repo 'docs/guards/candidates/ifx-gate-coverage-c6c1/Test-IFXC6DualPlatformCandidate.ps1'
    if (-not (Get-Content -LiteralPath $accepted -Raw).Contains($old)) { throw 'Non-vacuity: the accepted c6c1 script no longer shows the old path.' }
    [ordered]@{ scannedFiles = @(Get-ChildItem -LiteralPath $PSScriptRoot -File).Count }
}
# IFX-V4-003 behaviour controls.
Case 'installer-from-verified-archive' $false {
    $r = Get-IFX116ReleaseInstaller -ArchivePath $BaseArchivePath -ExpectedArchiveSha256 $ExpectedArchiveSha256 -Version '1.1.6' -WorkRoot (Join-Path $root 'good/work') -TargetRoot (Join-Path $root 'good/target')
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($BaseArchivePath)
    try {
        $entry = $zip.GetEntry('v4-guards-1.1.6/package/core/distribution/Install-V4Distribution.ps1')
        $stream = $entry.Open(); try { $entrySha = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)).ToLowerInvariant() } finally { $stream.Dispose() }
    } finally { $zip.Dispose() }
    if ($r.installerSha256 -cne $entrySha) { throw 'Extracted installer differs from the archive entry.' }
    if (-not $r.installerPath.StartsWith((Join-Path $root 'good/work'), [StringComparison]::OrdinalIgnoreCase)) { throw 'Installer is outside WorkRoot.' }
    [ordered]@{ installerSha256 = $r.installerSha256; extractedEntries = $r.extractedEntries }
}
Case 'archive-hash-drift-rejected' $true {
    $tampered = Join-Path $root 'tampered/v4-guards-1.1.6.zip'; [void][IO.Directory]::CreateDirectory((Split-Path -Parent $tampered))
    Copy-Item -LiteralPath $BaseArchivePath -Destination $tampered; [IO.File]::AppendAllText($tampered, 'x')
    Get-IFX116ReleaseInstaller -ArchivePath $tampered -ExpectedArchiveSha256 $ExpectedArchiveSha256 -Version '1.1.6' -WorkRoot (Join-Path $root 'tampered/work') -TargetRoot (Join-Path $root 'tampered/target')
}
Case 'extraction-under-target-rejected' $true {
    Get-IFX116ReleaseInstaller -ArchivePath $BaseArchivePath -ExpectedArchiveSha256 $ExpectedArchiveSha256 -Version '1.1.6' -WorkRoot (Join-Path $root 'undertarget/target/work') -TargetRoot (Join-Path $root 'undertarget/target')
}
Case 'wrong-version-rejected' $true {
    Get-IFX116ReleaseInstaller -ArchivePath $BaseArchivePath -ExpectedArchiveSha256 $ExpectedArchiveSha256 -Version '1.1.5' -WorkRoot (Join-Path $root 'wrongversion/work') -TargetRoot (Join-Path $root 'wrongversion/target')
}

# IFX-V4-002 storage controls in the pinned Linux image.
$imageId = (& docker image inspect --format '{{.Id}}' $LinuxImage).Trim()
if ($LASTEXITCODE -ne 0 -or $imageId -cne $LinuxImageDigest) { throw "Pinned Linux image missing or drifted: $imageId" }
$linuxOut = Join-Path $root 'linux'; $unlisted = Join-Path $root 'linux-unlisted'
[void][IO.Directory]::CreateDirectory($linuxOut); [void][IO.Directory]::CreateDirectory($unlisted)
$linuxLog = @(& docker run --rm --network none `
    --mount "type=bind,source=$repo,target=/source,readonly" --mount "type=bind,source=$linuxOut,target=/out" --mount "type=bind,source=$unlisted,target=/unlisted" `
    $LinuxImage pwsh -NoLogo -NoProfile -NonInteractive -File /source/docs/guards/candidates/ifx-rebind-116/Test-IFX116NativeStorageControls.ps1 -ReportPath /out/native-storage-controls.json 2>&1)
$linuxExit = $LASTEXITCODE
[IO.File]::WriteAllLines((Join-Path $root 'linux-controls.log'), [string[]]@($linuxLog | ForEach-Object { [string]$_ }), [Text.UTF8Encoding]::new($false))
$linuxReport = Join-Path $linuxOut 'native-storage-controls.json'
$linux = if (Test-Path -LiteralPath $linuxReport) { Get-Content -LiteralPath $linuxReport -Raw | ConvertFrom-Json -Depth 20 } else { $null }
$linuxPass = $linuxExit -eq 0 -and $null -ne $linux -and $linux.status -ceq 'pass'

$windowsPass = @($cases | Where-Object { -not $_.pass }).Count -eq 0
$status = if ($windowsPass -and $linuxPass) { 'pass' } else { 'failed' }
$summary = [ordered]@{
    formatVersion = 1; kind = 'ifx-i1-s4-harness-controls'; status = $status; planId = '20260928-v4-ifx-i1-rebind-1-1-6'
    harnessCommit = (& git -C $repo rev-parse HEAD).Trim(); linuxImageDigest = $imageId
    windowsCases = @($cases.ToArray())
    linux = [ordered]@{ exitCode = $linuxExit; report = $(if ($null -ne $linux) { [ordered]@{ path = 'linux/native-storage-controls.json'; sha256 = Hash $linuxReport } } else { $null }); cases = $(if ($null -ne $linux) { @($linux.cases) } else { @() }); fileSystems = $(if ($null -ne $linux) { $linux.fileSystems } else { $null }) }
}
[IO.File]::WriteAllText((Join-Path $root 'summary.json'), (($summary | ConvertTo-Json -Depth 20).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
$cases | ForEach-Object { "{0,-38} expected={1,-6} actual={2,-6} pass={3}" -f $_.id, $_.expected, $_.actual, $_.pass }
$linuxLog | ForEach-Object { "linux: $_" }
Write-Output "IFX I1 S4 harness controls $status`: $(Join-Path $root 'summary.json')"
if ($status -cne 'pass') { exit 1 }
