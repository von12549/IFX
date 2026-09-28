# IFX I1 (Plan 20260928-v4-ifx-i1-rebind-1-1-6) S4 negative controls for IFX-V4-002, run inside the pinned
# C6c Linux container by Test-IFX116HarnessControls.ps1 with /source (read-only) and /out bind-mounted.
param([Parameter(Mandatory)][string]$ReportPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'IFX116.NativeStorage.psm1') -Force
$cases = [Collections.Generic.List[object]]::new()
function Case([string]$Id, [bool]$ExpectReject, [scriptblock]$Body) {
    $message = $null; $rejected = $false
    try { $null = & $Body } catch { $rejected = $true; $message = $_.Exception.Message }
    $cases.Add([ordered]@{ id = $Id; expected = $(if ($ExpectReject) { 'reject' } else { 'accept' }); actual = $(if ($rejected) { 'reject' } else { 'accept' }); message = $message; pass = ($rejected -eq $ExpectReject) })
}
$binds = @('/out/linux', '/source')
$native = @('/native/linux/native-checkout', '/native/linux/work', '/native/linux/positive.json', '/native/linux/matrix/summary.json', '/native/linux/summary.json')
Case 'native-paths-accepted' $false { $r = Assert-IFX116NativeStorage -Paths $native -BindRoots $binds; if ($r -cne '/native/linux') { throw "root $r" } }
Case 'target-on-out-bind-rejected' $true { Assert-IFX116NativeStorage -Paths (@('/out/linux/native-checkout') + $native[1..4]) -BindRoots $binds }
Case 'work-on-out-bind-rejected' $true { Assert-IFX116NativeStorage -Paths @('/native/linux/native-checkout', '/out/linux/work', '/native/linux/positive.json', '/native/linux/matrix/summary.json', '/native/linux/summary.json') -BindRoots $binds }
Case 'all-on-out-bind-rejected' $true { Assert-IFX116NativeStorage -Paths @('/out/linux/native-checkout', '/out/linux/work', '/out/linux/positive.json', '/out/linux/matrix/summary.json', '/out/linux/summary.json') -BindRoots $binds }
Case 'target-under-source-rejected' $true { Assert-IFX116NativeStorage -Paths @('/source/x/native-checkout', '/source/x/work', '/source/x/positive.json', '/source/x/matrix/summary.json', '/source/x/summary.json') -BindRoots $binds }
Case 'path-outside-native-root-rejected' $true { Assert-IFX116NativeStorage -Paths @('/elsewhere/native-checkout', '/native/linux/work', '/native/linux/positive.json', '/native/linux/matrix/summary.json', '/native/linux/summary.json') -BindRoots $binds }
# The shared-file-system check does not depend on the bind-root list: a 9p path that is not declared as a
# bind root is still rejected (/unlisted is a separate bind mount of the same Windows directory).
Case 'undeclared-9p-mount-rejected' $true { Assert-IFX116NativeStorage -Paths @('/unlisted/linux/native-checkout', '/unlisted/linux/work', '/unlisted/linux/positive.json', '/unlisted/linux/matrix/summary.json', '/unlisted/linux/summary.json') -BindRoots $binds }
# Copy-back: every native result except the Target checkout reaches /out.
Case 'copyback-excludes-target' $false {
    foreach ($f in @('/native/cb/native-checkout/big.txt', '/native/cb/work/receipt.json', '/native/cb/linux-failure-direct-post.json')) { [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($f)); [IO.File]::WriteAllText($f, 'x') }
    Copy-IFX116NativeResults -NativeRoot '/native/cb' -OutRoot '/out/copyback' -Exclude @('native-checkout')
    if (Test-Path '/out/copyback/native-checkout') { throw 'Target checkout was copied back.' }
    foreach ($f in @('/out/copyback/work/receipt.json', '/out/copyback/linux-failure-direct-post.json', '/out/copyback/native-copyback.json')) { if (-not (Test-Path $f)) { throw "missing $f" } }
}
$fs = [ordered]@{ native = (& stat -f -c '%T' /native).Trim(); out = (& stat -f -c '%T' /out).Trim(); source = (& stat -f -c '%T' /source).Trim(); unlisted = (& stat -f -c '%T' /unlisted).Trim() }
$status = if (@($cases | Where-Object { -not $_.pass }).Count -eq 0) { 'pass' } else { 'failed' }
[IO.File]::WriteAllText($ReportPath, (([ordered]@{ formatVersion = 1; kind = 'ifx-i1-s4-native-storage-controls'; status = $status; fileSystems = $fs; cases = @($cases.ToArray()) } | ConvertTo-Json -Depth 10).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
$cases | ForEach-Object { "{0,-34} expected={1,-6} actual={2,-6} pass={3}" -f $_.id, $_.expected, $_.actual, $_.pass }
if ($status -cne 'pass') { exit 1 }
