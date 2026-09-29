# IFX I2-B (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step B1: IFX-V4-006 benchmark. The tree is a replica
# of the real I1 C6c Linux results (artifacts/guards/p10-ifx-116/c6c-full/linux: matrix, work and the two
# reports; the old copy-back manifest is left out), which is more faithful than a synthetic tree of the same size.
# -Phase Windows (default) packs the replica on the Windows side, starts the pinned Linux image with the C6c bind
# layout, and -Phase Linux unpacks it onto container-native storage and times both copy-back methods to the
# Windows bind mount: the I1 per-file copy (Copy-IFX116NativeResults) and the I2-B archive copy
# (Copy-IFXI2BNativeResults). The Windows phase then re-checks the archive with -Deep and compares its listing with
# the original replica source.
[CmdletBinding()]
param(
    [ValidateSet('Windows', 'Linux')][string]$Phase = 'Windows',
    [Parameter(Mandatory)][string]$BenchRoot,
    [string]$ReplicaSource = 'D:/IFX-Root/IFX/artifacts/guards/p10-ifx-116/c6c-full/linux',
    [string]$RecordPath,
    [string]$SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path,
    [string]$LinuxImage = 'ifx-c6c-sdk:10.0.303',
    [string]$LinuxImageDigest = 'sha256:7d373379cf99594538947415d2770f0823a39e3c957cf7e81488370561168773'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'IFXI2B.NativeArchive.psm1') -Force
$replicaItems = @('matrix', 'positive.json', 'summary.json', 'work')

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-Json([string]$Path, $Value) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path)))
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 20).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
}
function Count-Files([string]$Root) { if (Test-Path -LiteralPath $Root) { @(Get-ChildItem -LiteralPath $Root -File -Recurse -Force).Count } else { 0 } }

if ($Phase -ceq 'Linux') {
    if (-not $IsLinux) { throw 'Phase Linux runs inside the pinned Linux image.' }
    Import-Module /source/docs/guards/candidates/ifx-rebind-116/IFX116.NativeStorage.psm1 -Force
    $native = '/native/bench/linux'
    [void][IO.Directory]::CreateDirectory($native)
    $t = [Diagnostics.Stopwatch]::StartNew()
    $x = @(& (Get-IFXI2BTar) -xf /in/replica.tar -C $native 2>&1); if ($LASTEXITCODE -ne 0) { throw "Replica extraction failed: $($x -join '; ')" }
    $unpackSeconds = [math]::Round($t.Elapsed.TotalSeconds, 3)
    $files = Count-Files $native
    $bytes = [long]((Get-ChildItem -LiteralPath $native -File -Recurse -Force | Measure-Object Length -Sum).Sum)
    $fs = (& stat -f -c '%T' $native).Trim(); $outFs = (& stat -f -c '%T' /out).Trim()

    $t.Restart()
    Copy-IFXI2BNativeResults -NativeRoot $native -OutRoot /out/archive
    $archiveSeconds = [math]::Round($t.Elapsed.TotalSeconds, 3)
    $t.Restart()
    Copy-IFX116NativeResults -NativeRoot $native -OutRoot /out/perfile
    $perFileSeconds = [math]::Round($t.Elapsed.TotalSeconds, 3)

    Write-Json /out/linux-bench.json ([ordered]@{
        formatVersion = 1; nativeRoot = $native; nativeFileSystem = $fs; outFileSystem = $outFs
        replicaFiles = $files; replicaBytes = $bytes; unpackSeconds = $unpackSeconds
        archiveCopyBackSeconds = $archiveSeconds; perFileCopyBackSeconds = $perFileSeconds
        perFileOutputFiles = Count-Files /out/perfile
    })
    "archive $archiveSeconds s; per-file $perFileSeconds s; files $files"
    exit 0
}

# Windows phase.
if (Test-Path -LiteralPath $BenchRoot) { throw "BenchRoot already exists: $BenchRoot" }
[void][IO.Directory]::CreateDirectory($BenchRoot)
$bench = (Resolve-Path -LiteralPath $BenchRoot).Path
$source = (Resolve-Path -LiteralPath $ReplicaSource).Path
$imageId = (& docker image inspect --format '{{.Id}}' $LinuxImage).Trim()
if ($LASTEXITCODE -ne 0 -or $imageId -cne $LinuxImageDigest) { throw "Pinned Linux image digest mismatch: $imageId" }

$t = [Diagnostics.Stopwatch]::StartNew()
foreach ($item in $replicaItems) {
    $full = Join-Path $source $item
    if (-not (Test-Path -LiteralPath $full)) { throw "Replica source item missing: $item" }
}
$exclude = @(Get-ChildItem -LiteralPath $source -Force | Where-Object { $replicaItems -cnotcontains $_.Name } | ForEach-Object Name)
$sourceListing = Get-IFXI2BTreeListing -Root $source -Exclude $exclude
$sourceListingSeconds = [math]::Round($t.Elapsed.TotalSeconds, 3)
$in = Join-Path $bench 'in'; [void][IO.Directory]::CreateDirectory($in)
$t.Restart()
$x = @(& (Get-IFXI2BTar) -cf (Join-Path $in 'replica.tar') -C $source @replicaItems 2>&1); if ($LASTEXITCODE -ne 0) { throw "Replica pack failed: $($x -join '; ')" }
$packSeconds = [math]::Round($t.Elapsed.TotalSeconds, 3)
$out = Join-Path $bench 'out'; [void][IO.Directory]::CreateDirectory($out)

$t.Restart()
$linuxOutput = @(& docker run --rm --network none --mount "type=bind,source=$SourceRoot,target=/source,readonly" --mount "type=bind,source=$in,target=/in,readonly" `
    --mount "type=bind,source=$out,target=/out" $LinuxImage pwsh -NoLogo -NoProfile -NonInteractive -File /source/docs/guards/candidates/ifx-i2b/Invoke-IFXI2BCopyBackBenchmark.ps1 -Phase Linux -BenchRoot /out 2>&1)
$linuxExit = $LASTEXITCODE; $containerSeconds = [math]::Round($t.Elapsed.TotalSeconds, 3)
[IO.File]::WriteAllText((Join-Path $bench 'linux-phase.log'), (($linuxOutput | ForEach-Object { [string]$_ }) -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
if ($linuxExit -ne 0) { throw "Linux benchmark phase failed ($linuxExit): $(@($linuxOutput | Select-Object -Last 5) -join '; ')" }
$linux = Get-Content -LiteralPath (Join-Path $out 'linux-bench.json') -Raw | ConvertFrom-Json -Depth 20

$t.Restart()
$verify = Test-IFXI2BNativeArchive -OutRoot (Join-Path $out 'archive') -Deep
$verifySeconds = [math]::Round($t.Elapsed.TotalSeconds, 3)
$archiveListing = [IO.File]::ReadAllText((Join-Path $out 'archive/native-listing.txt'))
$sourceListingText = (@($sourceListing | ForEach-Object { "$($_.sha256) $($_.bytes) $($_.path)" }) -join "`n") + "`n"
$listingEqual = $archiveListing -ceq $sourceListingText
$manifest = Get-Content -LiteralPath (Join-Path $out 'archive/native-copyback.json') -Raw | ConvertFrom-Json -Depth 20
$perFileCount = Count-Files (Join-Path $out 'perfile')
$status = if ($listingEqual -and $manifest.status -ceq 'pass' -and $linux.perFileOutputFiles -ge $sourceListing.Count -and $linux.archiveCopyBackSeconds -lt $linux.perFileCopyBackSeconds) { 'pass' } else { 'fail' }
$record = [ordered]@{
    formatVersion = 1; kind = 'ifx-i2b-b1-copyback-benchmark'; status = $status
    sourceCommit = (& git -C $SourceRoot rev-parse HEAD).Trim()
    module = [ordered]@{ path = 'docs/guards/candidates/ifx-i2b/IFXI2B.NativeArchive.psm1'; sha256 = Hash (Join-Path $PSScriptRoot 'IFXI2B.NativeArchive.psm1') }
    linuxImage = $LinuxImage; linuxImageDigest = $imageId
    replica = [ordered]@{ source = $ReplicaSource.Replace('\', '/'); items = $replicaItems; files = $sourceListing.Count; bytes = $linux.replicaBytes; nativeFileSystem = $linux.nativeFileSystem; outFileSystem = $linux.outFileSystem }
    seconds = [ordered]@{
        perFileCopyBack = $linux.perFileCopyBackSeconds; archiveCopyBack = $linux.archiveCopyBackSeconds
        archivePhases = $manifest.timings; windowsDeepVerify = $verifySeconds
        speedup = [math]::Round($linux.perFileCopyBackSeconds / [math]::Max($linux.archiveCopyBackSeconds, 0.001), 1)
        replicaSourceListing = $sourceListingSeconds; replicaPack = $packSeconds; replicaUnpack = $linux.unpackSeconds; container = $containerSeconds
    }
    archive = $manifest.archive; listing = $manifest.listing
    archiveListingEqualsReplicaSource = $listingEqual
    windowsDeepVerify = $verify
    perFileOutputFiles = $perFileCount
}
Write-Json (Join-Path $bench 'benchmark.json') $record
if ($RecordPath) { Write-Json $RecordPath $record }
"benchmark ${status}: per-file $($linux.perFileCopyBackSeconds) s, archive $($linux.archiveCopyBackSeconds) s, speed-up x$($record.seconds.speedup), listing equal $listingEqual"
if ($status -cne 'pass') { exit 1 }
