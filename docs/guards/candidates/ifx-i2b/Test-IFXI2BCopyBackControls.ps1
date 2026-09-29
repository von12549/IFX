# IFX I2-B (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step B1: controls for the IFX-V4-006 archive
# copy-back (IFXI2B.NativeArchive.psm1). -Phase Windows (default) starts the pinned Linux image with the same bind
# layout as the C6c parallel runner (read-only /source, writable /out on the Windows disk), runs -Phase Linux
# inside it, then re-checks the Linux output with the Windows tar and runs the same negative cases there.
[CmdletBinding()]
param(
    [ValidateSet('Windows', 'Linux')][string]$Phase = 'Windows',
    [Parameter(Mandatory)][string]$OutRoot,
    [string]$SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path,
    [string]$LinuxImage = 'ifx-c6c-sdk:10.0.303',
    [string]$LinuxImageDigest = 'sha256:7d373379cf99594538947415d2770f0823a39e3c957cf7e81488370561168773'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'IFXI2B.NativeArchive.psm1') -Force

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Write-Json([string]$Path, $Value) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path)))
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 20).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
}
$cases = [Collections.Generic.List[object]]::new()
function Case([string]$Name, [bool]$ExpectReject, [scriptblock]$Body) {
    $diagnostic = $null; $rejected = $false
    try { $null = & $Body } catch { $rejected = $true; $diagnostic = $_.Exception.Message }
    $pass = $rejected -eq $ExpectReject
    $cases.Add([ordered]@{ name = $Name; expected = $(if ($ExpectReject) { 'reject' } else { 'accept' }); actual = $(if ($rejected) { 'reject' } else { 'accept' }); pass = $pass; diagnostic = $diagnostic })
}
function Clone-Out([string]$From, [string]$Name) {
    $to = Join-Path ([IO.Path]::GetDirectoryName($From)) $Name
    if (Test-Path -LiteralPath $to) { Remove-Item -LiteralPath $to -Recurse -Force }
    Copy-Item -LiteralPath $From -Destination $to -Recurse
    $to
}
function Update-Manifest([string]$Root, [scriptblock]$Change) {
    $p = Join-Path $Root 'native-copyback.json'
    $m = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json -Depth 20
    & $Change $m
    Write-Json $p $m
}
function Invoke-NegativeCases([string]$Good, [string]$Prefix) {
    # Each case changes one copy of a passing output and must be rejected by Test-IFXI2BNativeArchive.
    Case "$Prefix-verify-deep" $false { Test-IFXI2BNativeArchive -OutRoot $Good -Deep }
    $c = Clone-Out $Good "$Prefix-truncated"
    $a = Join-Path $c 'native-results.tar.gz'; $bytes = [IO.File]::ReadAllBytes($a); [IO.File]::WriteAllBytes($a, $bytes[0..([int]($bytes.Length / 2))])
    Case "$Prefix-truncated-archive-rejected" $true { Test-IFXI2BNativeArchive -OutRoot $c }
    $c = Clone-Out $Good "$Prefix-truncated-rehashed"
    $a = Join-Path $c 'native-results.tar.gz'; $bytes = [IO.File]::ReadAllBytes($a); [IO.File]::WriteAllBytes($a, $bytes[0..([int]($bytes.Length / 2))])
    $sha = Hash $a; Update-Manifest $c { param($m) $m.archive.sha256 = $sha }
    Case "$Prefix-truncated-archive-with-matching-manifest-rejected" $true { Test-IFXI2BNativeArchive -OutRoot $c }
    $c = Clone-Out $Good "$Prefix-listing-short"
    $l = Join-Path $c 'native-listing.txt'; $lines = @([IO.File]::ReadAllText($l).Split("`n", [StringSplitOptions]::RemoveEmptyEntries))
    [IO.File]::WriteAllText($l, (($lines | Select-Object -Skip 1) -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
    $sha = Hash $l; $n = $lines.Count - 1; Update-Manifest $c { param($m) $m.listing.sha256 = $sha; $m.listing.files = $n }
    Case "$Prefix-listing-missing-archived-file-rejected" $true { Test-IFXI2BNativeArchive -OutRoot $c }
    $c = Clone-Out $Good "$Prefix-report-tampered"
    $r = Join-Path $c 'summary.json'; [IO.File]::AppendAllText($r, ' ')
    Case "$Prefix-copied-report-tampered-rejected" $true { Test-IFXI2BNativeArchive -OutRoot $c }
    $c = Clone-Out $Good "$Prefix-report-consistent-forgery"
    # The copied report, its manifest row and its listing row all agree; only the archived bytes differ.
    $r = Join-Path $c 'summary.json'; [IO.File]::AppendAllText($r, ' '); $rs = Hash $r
    $l = Join-Path $c 'native-listing.txt'
    $text = ([IO.File]::ReadAllText($l).Split("`n", [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $p = $_.Split(' ', 3); if ($p[2] -ceq 'summary.json') { "$rs $((Get-Item -LiteralPath $r).Length) summary.json" } else { $_ } }) -join "`n"
    [IO.File]::WriteAllText($l, $text + "`n", [Text.UTF8Encoding]::new($false)); $ls = Hash $l
    Update-Manifest $c { param($m) $m.listing.sha256 = $ls; foreach ($x in $m.reports) { if ($x.path -ceq 'summary.json') { $x.sha256 = $rs } } }
    Case "$Prefix-report-forgery-against-archive-rejected" $true { Test-IFXI2BNativeArchive -OutRoot $c }
    $c = Clone-Out $Good "$Prefix-report-missing"
    Remove-Item -LiteralPath (Join-Path $c 'matrix/case-manifest.json')
    Case "$Prefix-copied-report-missing-rejected" $true { Test-IFXI2BNativeArchive -OutRoot $c }
    $c = Clone-Out $Good "$Prefix-deep-content"
    # Rewrite one archived non-report file and re-hash the archive: only -Deep sees the listing mismatch.
    $x = Join-Path $c 'x'; [void][IO.Directory]::CreateDirectory($x)
    $null = & (Get-IFXI2BTar) -xzf (Join-Path $c 'native-results.tar.gz') -C $x; if ($LASTEXITCODE -ne 0) { throw 'extract failed' }
    [IO.File]::AppendAllText((Join-Path $x 'matrix/captures/c01/case-001.json'), 'x')
    $null = & (Get-IFXI2BTar) -czf (Join-Path $c 'native-results.tar.gz') -C $x .; if ($LASTEXITCODE -ne 0) { throw 'repack failed' }
    Remove-Item -LiteralPath $x -Recurse -Force
    $sha = Hash (Join-Path $c 'native-results.tar.gz'); Update-Manifest $c { param($m) $m.archive.sha256 = $sha }
    Case "$Prefix-rehashed-archive-content-change-deep-rejected" $true { Test-IFXI2BNativeArchive -OutRoot $c -Deep }
    $c = Clone-Out $Good "$Prefix-failed-manifest"
    Update-Manifest $c { param($m) $m.status = 'fail' }
    Case "$Prefix-failed-copyback-manifest-rejected" $true { Test-IFXI2BNativeArchive -OutRoot $c }
}

if ($Phase -ceq 'Linux') {
    if (-not $IsLinux) { throw 'Phase Linux runs inside the pinned Linux image.' }
    $native = '/native/cb/linux'
    if (Test-Path -LiteralPath '/native/cb') { Remove-Item -LiteralPath '/native/cb' -Recurse -Force }
    $files = [ordered]@{
        'summary.json' = '{"status":"pass"}'; 'positive.json' = '{"status":"pass","cases":[]}'
        'matrix/summary.json' = '{"status":"pass","provenCoreCases":191}'; 'matrix/case-manifest.json' = '{"cases":[]}'
        'matrix/suites/c01/linux-failure-direct-post.json' = '{"status":"fail"}'; 'work/base-receipt.json' = '{"receipt":1}'
        'native-checkout/README.md' = 'excluded checkout'
    }
    for ($i = 1; $i -le 40; $i++) { $files["matrix/captures/c01/case-$('{0:d3}' -f $i).json"] = ('{"case":' + $i + ',"pad":"' + ('x' * (37 * $i)) + '"}') }
    foreach ($k in $files.Keys) { $p = Join-Path $native $k; [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($p)); [IO.File]::WriteAllText($p, $files[$k], [Text.UTF8Encoding]::new($false)) }
    $good = Join-Path $OutRoot 'linux/good'
    Copy-IFXI2BNativeResults -NativeRoot $native -OutRoot $good -Exclude @('native-checkout') -Reports @('summary.json', 'positive.json', 'matrix/summary.json', 'matrix/case-manifest.json', 'matrix/absent-report.json')
    $m = Get-Content -LiteralPath (Join-Path $good 'native-copyback.json') -Raw | ConvertFrom-Json -Depth 20
    Case 'linux-copyback-pass' $false { if ($m.status -cne 'pass') { throw "status $($m.status): $(@($m.diagnostics) -join '; ')" } }
    Case 'linux-listing-equals-native-tree' $false {
        $expected = @($files.Keys | Where-Object { -not $_.StartsWith('native-checkout/') })
        $listed = @([IO.File]::ReadAllText((Join-Path $good 'native-listing.txt')).Split("`n", [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $_.Split(' ', 3)[2] })
        $el = [Collections.Generic.List[string]]::new([string[]]$expected); $el.Sort([StringComparer]::Ordinal); $e = $el.ToArray()
        if (($listed -join '|') -cne ($e -join '|')) { throw "listing $($listed.Count) vs tree $($e.Count)" }
        if ($m.archive.fileEntries -ne $e.Count) { throw 'archive entry count differs' }
    }
    Case 'linux-excluded-checkout-not-archived' $false { if (@([IO.File]::ReadAllLines((Join-Path $good 'native-listing.txt')) | Where-Object { $_ -match ' native-checkout/' }).Count -ne 0) { throw 'checkout archived' } }
    Case 'linux-reports-byte-identical' $false {
        foreach ($r in @($m.reports | Where-Object { $_.present })) { if ((Hash (Join-Path $good $r.path)) -cne (Hash (Join-Path $native $r.path))) { throw "differs: $($r.path)" } }
        $want = @('matrix/case-manifest.json', 'matrix/suites/c01/linux-failure-direct-post.json', 'matrix/summary.json', 'positive.json', 'summary.json')
        $got = @($m.reports | Where-Object { $_.present } | ForEach-Object { $_.path }); if (($got -join '|') -cne ($want -join '|')) { throw "reports: $($got -join ',')" }
    }
    Case 'linux-bulk-files-not-copied-individually' $false { if (Test-Path -LiteralPath (Join-Path $good 'matrix/captures')) { throw 'captures copied per file' }; if (Test-Path -LiteralPath (Join-Path $good 'work')) { throw 'work copied per file' } }
    Case 'linux-absent-report-recorded' $false { if (@($m.reports | Where-Object { $_.path -ceq 'matrix/absent-report.json' -and -not $_.present }).Count -ne 1) { throw 'absent report not recorded' } }
    Case 'linux-staging-archive-removed' $false { if (Test-Path -LiteralPath '/native/cb/linux-native-results.tar.gz') { throw 'staging archive left on native storage' } }
    $missing = Join-Path $OutRoot 'linux/missing-root'
    Case 'linux-missing-native-root-records-fail-without-throw' $false {
        Copy-IFXI2BNativeResults -NativeRoot '/native/cb/absent' -OutRoot $missing -WarningAction SilentlyContinue
        $mm = Get-Content -LiteralPath (Join-Path $missing 'native-copyback.json') -Raw | ConvertFrom-Json -Depth 20
        if ($mm.status -cne 'fail' -or @($mm.diagnostics).Count -ne 1) { throw 'missing root not recorded as fail' }
    }
    if ($m.status -ceq 'pass') { Invoke-NegativeCases $good 'linux' }
    Write-Json (Join-Path $OutRoot 'linux/controls.json') ([ordered]@{ formatVersion = 1; phase = 'linux'; tar = (& (Get-IFXI2BTar) --version | Select-Object -First 1); cases = @($cases.ToArray()) })
    $failed = @($cases | Where-Object { -not $_.pass })
    "linux controls: $($cases.Count) cases, $($failed.Count) failed"
    if ($failed.Count -gt 0) { $failed | ForEach-Object { "FAIL $($_.name): $($_.diagnostic)" }; exit 1 }
    exit 0
}

# Windows phase.
if (Test-Path -LiteralPath $OutRoot) { throw "OutRoot already exists: $OutRoot" }
[void][IO.Directory]::CreateDirectory($OutRoot)
$out = (Resolve-Path -LiteralPath $OutRoot).Path
$imageId = (& docker image inspect --format '{{.Id}}' $LinuxImage).Trim()
if ($LASTEXITCODE -ne 0 -or $imageId -cne $LinuxImageDigest) { throw "Pinned Linux image digest mismatch: $imageId" }
$linuxOutput = @(& docker run --rm --network none --mount "type=bind,source=$SourceRoot,target=/source,readonly" --mount "type=bind,source=$out,target=/out" `
    $LinuxImage pwsh -NoLogo -NoProfile -NonInteractive -File /source/docs/guards/candidates/ifx-i2b/Test-IFXI2BCopyBackControls.ps1 -Phase Linux -OutRoot /out 2>&1)
$linuxExit = $LASTEXITCODE
[IO.File]::WriteAllText((Join-Path $out 'linux-phase.log'), (($linuxOutput | ForEach-Object { [string]$_ }) -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
$good = Join-Path $out 'linux/good'
if ($linuxExit -eq 0) {
    # The Windows re-check runs on a copy so the Linux-side case directories stay as produced.
    Copy-Item -LiteralPath $good -Destination (Join-Path $out 'windows-good') -Recurse

    Invoke-NegativeCases (Join-Path $out 'windows-good') 'windows'
}
$linuxControls = Join-Path $out 'linux/controls.json'
$linux = if (Test-Path -LiteralPath $linuxControls) { Get-Content -LiteralPath $linuxControls -Raw | ConvertFrom-Json -Depth 20 } else { $null }
$allCases = @(@(if ($null -ne $linux) { $linux.cases }) + @($cases.ToArray()))
$failed = @($allCases | Where-Object { -not $_.pass })
$status = if ($linuxExit -eq 0 -and $null -ne $linux -and $cases.Count -gt 0 -and $failed.Count -eq 0) { 'pass' } else { 'fail' }
Write-Json (Join-Path $out 'summary.json') ([ordered]@{
    formatVersion = 1; kind = 'ifx-i2b-b1-copyback-controls'; status = $status
    sourceCommit = (& git -C $SourceRoot rev-parse HEAD).Trim()
    module = [ordered]@{ path = 'docs/guards/candidates/ifx-i2b/IFXI2B.NativeArchive.psm1'; sha256 = Hash (Join-Path $PSScriptRoot 'IFXI2B.NativeArchive.psm1') }
    linuxImage = $LinuxImage; linuxImageDigest = $imageId; linuxExitCode = $linuxExit
    windowsTar = ((& (Get-IFXI2BTar) --version) | Select-Object -First 1)
    caseCount = $allCases.Count; failedCount = $failed.Count; cases = $allCases
})
"copy-back controls: $($allCases.Count) cases, $($failed.Count) failed, status $status"
if ($status -cne 'pass') { $failed | ForEach-Object { "FAIL $($_.name): $($_.diagnostic)" }; exit 1 }
