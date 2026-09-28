# IFX I1 (Plan 20260928-v4-ifx-i1-rebind-1-1-6) step S4: negative controls for the C6c Linux harness
# successors. IFX-V4-003: the installer comes only from the hash-verified release archive. IFX-V4-002: every
# Linux working path is on container-native storage. Runs on Windows; the storage controls run in the
# pinned Linux image with the network disabled.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [string]$InventoryPath,
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

# IFX-V4-003/004 static control: no I1 harness file names the removed incubation path in any letter case
# (T8 missed the upper-case docs/guards/V4 references). The only allowed occurrence is the pinned Git blob
# path inside fixture-spec-116.json. The accepted c6c1 script and c6c4 contract still show the old path, so
# the scan is not vacuous.
$oldPattern = '(?i)docs[/\\]guards[/\\]v4[/\\]'
Case 'no-harness-file-uses-docs-guards-v4' $false {
    $hits = [Collections.Generic.List[string]]::new()
    foreach ($file in @(Get-ChildItem -LiteralPath $PSScriptRoot -File)) {
        $text = Get-Content -LiteralPath $file.FullName -Raw
        if ($file.Name -ceq 'fixture-spec-116.json') {
            $spec = $text | ConvertFrom-Json -Depth 50
            $blobPaths = @($spec.sourceSuites.PSObject.Properties | Where-Object { $null -ne $_.Value.PSObject.Properties['gitBlob'] } | ForEach-Object { [string]$_.Value.gitBlob.path })
            foreach ($p in $blobPaths) { $text = $text.Replace($p, '<pinned-git-blob-path>') }
        }
        if ($text -match $oldPattern) { $hits.Add($file.Name) }
    }
    if ($hits.Count -ne 0) { throw "Harness files reference the removed path: $($hits -join ', ')" }
    foreach ($accepted in @('docs/guards/candidates/ifx-gate-coverage-c6c1/Test-IFXC6DualPlatformCandidate.ps1', 'docs/guards/candidates/ifx-gate-coverage-c6c4/matrix-contract.json')) {
        if ((Get-Content -LiteralPath (Join-Path $repo $accepted) -Raw) -notmatch $oldPattern) { throw "Non-vacuity: $accepted no longer shows the old path." }
    }
    [ordered]@{ scannedFiles = @(Get-ChildItem -LiteralPath $PSScriptRoot -File).Count }
}

# IFX-V4-004 (amendment A4) controls: V4 reference inputs from the verified base release and a pinned blob.
Import-Module (Join-Path $PSScriptRoot 'IFX116.V4Reference.psm1') -Force
$baseInstall = 'D:/IFX-Root/guard-runtime/releases/v4-guards-1.1.6'
Case 'a4-base-reference-verified' $false { [ordered]@{ package = (Assert-IFX116V4BaseReference -BaseInstallRoot $baseInstall) } }
Case 'a4-base-reference-drift-rejected' $true {
    $fake = Join-Path $root 'a4-drift/base'
    foreach ($rel in (Get-IFX116V4PinnedBaseFiles).Keys) { $dst = Join-Path $fake "package/$rel"; [void][IO.Directory]::CreateDirectory((Split-Path -Parent $dst)); Copy-Item -LiteralPath (Join-Path $baseInstall "package/$rel") -Destination $dst }
    [IO.File]::AppendAllText((Join-Path $fake 'package/modules/architecture-conformance/adapter.ps1'), "`n# drift")
    Assert-IFX116V4BaseReference -BaseInstallRoot $fake
}
Case 'a4-accepted-suites-converted' $false {
    $suites = @(Get-ChildItem -LiteralPath (Join-Path $repo 'docs/guards/candidates') -Recurse -File -Filter 'Test-IFX*.ps1' | Where-Object { $_.FullName -match 'ifx-gate-coverage-c\d' -and (Get-Content -LiteralPath $_.FullName -Raw) -match $oldPattern -and $_.Name -cne 'Test-IFXC6DualPlatformCandidate.ps1' })
    if ($suites.Count -ne 17) { throw "Expected 17 accepted suites with V4 schema lookups, found $($suites.Count)" }
    $package = Assert-IFX116V4BaseReference -BaseInstallRoot $baseInstall
    foreach ($s in $suites) { $converted = Convert-IFX116V4SchemaReferences -Source (Get-Content -LiteralPath $s.FullName -Raw) -BaseInstallRoot $baseInstall; if (-not $converted.Contains($package)) { throw "Conversion did not redirect: $($s.Name)" } }
    [ordered]@{ convertedSuites = $suites.Count }
}
Case 'a4-unconvertible-reference-rejected' $true {
    $removed = 'docs/guards/' + 'V4/tests/p4/Test-V4ArchUnitNetAdapter.ps1'
    Convert-IFX116V4SchemaReferences -Source "`$x = Join-Path `$repoRoot '$removed'" -BaseInstallRoot $baseInstall
}
Case 'a4-git-blob-verified' $false {
    $bytes = Get-IFX116GitBlobBytes -RepositoryRoot $repo -Commit '896bca2442a0bff9f8bc8bf1a7826e5621acbf07' -Path ('docs/guards/' + 'v4/tests/p4/Test-V4ArchUnitNetAdapter.ps1') -BlobId '591ee4774c4a72ae44c6804ccd3dc4eb9d5b3713'
    $sha = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
    if ($sha -cne '69be54c3e6968f82217d7fb904a788fb177dc28568b875150ebec37304b8431e') { throw "Blob content hash $sha" }
    [ordered]@{ sha256 = $sha; bytes = $bytes.Length }
}
Case 'a4-git-blob-mismatch-rejected' $true {
    Get-IFX116GitBlobBytes -RepositoryRoot $repo -Commit '896bca2442a0bff9f8bc8bf1a7826e5621acbf07' -Path ('docs/guards/' + 'v4/tests/p4/Test-V4ArchUnitNetAdapter.ps1') -BlobId ('0' * 40)
}
Case 'a4-removed-path-resolution-rejected' $true {
    Resolve-IFX116V4Path -Path ('docs/guards/' + 'V4/modules/architecture-conformance/adapter.ps1') -RepositoryRoot $repo -BaseInstallRoot $baseInstall
}
Case 'a4-unpinned-base-reference-rejected' $true {
    Resolve-IFX116V4Path -Path 'base-package:modules/architecture-conformance/module.json' -RepositoryRoot $repo -BaseInstallRoot $baseInstall
}
if ($InventoryPath) {
    $verifier = Join-Path $PSScriptRoot 'Test-IFX116MatrixContract.ps1'
    Case 'a4-contract-verifier-pass' $false {
        $out = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $verifier -RepositoryRoot $repo -BaseInstallRoot $baseInstall -InventoryPath $InventoryPath -ReportPath (Join-Path $root 'a4-verifier/summary.json') 2>&1)
        if ($LASTEXITCODE -ne 0) { throw ($out -join ' ') }
        [ordered]@{ report = 'a4-verifier/summary.json' }
    }
    Case 'a4-contract-verifier-rejects-removed-adapter-path' $true {
        $dir = Join-Path $root 'a4-verifier-removed'; [void][IO.Directory]::CreateDirectory($dir)
        $contractText = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'matrix-contract-116.json') -Raw).Replace('base-package:modules/architecture-conformance/adapter.ps1', ('docs/guards/' + 'V4/modules/architecture-conformance/adapter.ps1'))
        $contractPath = Join-Path $dir 'matrix-contract.json'; [IO.File]::WriteAllText($contractPath, $contractText, [Text.UTF8Encoding]::new($false))
        $spec = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'fixture-spec-116.json') -Raw) -replace '"matrixContractSha256": "[0-9a-f]{64}"', ('"matrixContractSha256": "' + (Hash $contractPath) + '"')
        $specPath = Join-Path $dir 'fixture-spec.json'; [IO.File]::WriteAllText($specPath, $spec, [Text.UTF8Encoding]::new($false))
        $out = @(& pwsh -NoLogo -NoProfile -NonInteractive -File $verifier -RepositoryRoot $repo -BaseInstallRoot $baseInstall -InventoryPath $InventoryPath -ContractPath $contractPath -FixtureSpecPath $specPath -ReportPath (Join-Path $dir 'summary.json') 2>&1)
        if ($LASTEXITCODE -ne 0) { throw ($out -join ' ') }
    }
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
