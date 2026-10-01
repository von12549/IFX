# IFX I2-B amendment A2 step A2-6: the 0.5.1 module-suite index for the contract handshake. The 20 modules that 0.5.1
# keeps byte-identical to 0.5.0-a take their passing A1-3 records; the five lock consumers whose producer moved take their
# passing A2-5 records. Every record must match the current adapter (and policy) of its module in this tree.
[CmdletBinding()]
param(
    [string]$A13IndexPath = 'artifacts/guards/p10-ifx-i2b/a1-suites/index.json',
    [string]$A25IndexPath = 'artifacts/guards/p10-ifx-i2b/a2-relocation/a2-5-suites/index.json',
    [string]$OutputPath = 'artifacts/guards/p10-ifx-i2b/a2-relocation/suite-index-051.json'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'IFX050.Tooling.psm1') -Force
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }
$a13 = Get-Content (Full $A13IndexPath) -Raw | ConvertFrom-Json -Depth 50
$a25 = Get-Content (Full $A25IndexPath) -Raw | ConvertFrom-Json -Depth 50
if ($a13.kind -cne 'ifx-050a-module-suites' -or $a13.summary.passed -ne 25 -or $a13.summary.failed -ne 0) { throw 'A1-3 index is not 25 passing modules.' }
if ($a25.kind -cne 'ifx-051-suite-outcomes' -or $a25.status -cne 'pass' -or @($a25.modules).Count -ne 5) { throw 'A2-5 record is not five passing modules.' }
$moved = @{}; foreach ($m in @($a25.modules)) { $moved[[string]$m.moduleId] = $m }
$rows = foreach ($r in @($a13.modules)) {
    $id = [string]$r.moduleId; $root = Join-Path $PSScriptRoot "modules/$id"
    $adapter = Get-IFX050Sha256 (Join-Path $root 'adapter.ps1'); $policyPath = Join-Path $root 'policy.json'; $policy = if ([IO.File]::Exists($policyPath)) { Get-IFX050Sha256 $policyPath } else { $null }
    $version = (Get-Content (Join-Path $root 'module.json') -Raw | ConvertFrom-Json).version
    if ($moved.ContainsKey($id)) {
        $m = $moved[$id]; $summary = Join-Path (Split-Path -Parent (Full $A25IndexPath)) "$id.summary.json"; $s = Get-Content $summary -Raw | ConvertFrom-Json -Depth 50
        if ($s.adapterSha256 -cne $adapter -or ($policy -and $s.policySha256 -cne $policy) -or $m.status -cne 'pass' -or $m.failed -ne 0 -or $s.version -cne $version) { throw "A2-5 record does not match the current module: $id" }
        [ordered]@{ moduleId = $id; version = $version; status = 'pass'; cases = $m.cases; failed = 0; adapterSha256 = $adapter; policySha256 = $policy; targetCommit = $m.targetCommit; host = $m.host; source = 'A2-5'; summarySha256 = $m.summarySha256 }
    } else {
        if ($r.adapterSha256 -cne $adapter -or ($policy -and $r.policySha256 -cne $policy) -or $r.status -cne 'pass' -or $r.version -cne $version) { throw "A1-3 record does not match the unchanged module: $id" }
        [ordered]@{ moduleId = $id; version = $version; status = 'pass'; cases = $r.cases; failed = 0; adapterSha256 = $adapter; policySha256 = $policy; targetCommit = $r.targetCommit; host = $r.host; source = 'A1-3'; summarySha256 = $r.summarySha256 }
    }
}
if (@($rows | Where-Object { $_.source -ceq 'A2-5' }).Count -ne 5) { throw 'Not every moved module is in the A1-3 index.' }
Write-IFX050Json (Full $OutputPath) ([ordered]@{ formatVersion = 1; kind = 'ifx-050a-module-suites'; step = 'A2-6'; version = '0.5.1'
    sources = [ordered]@{ a13 = [ordered]@{ path = $A13IndexPath; sha256 = Get-IFX050Sha256 (Full $A13IndexPath) }; a25 = [ordered]@{ path = $A25IndexPath; sha256 = Get-IFX050Sha256 (Full $A25IndexPath) } }
    summary = [ordered]@{ modules = @($rows).Count; passed = @($rows).Count; failed = 0; fromA13 = @($rows | Where-Object { $_.source -ceq 'A1-3' }).Count; fromA25 = 5 }
    modules = @($rows) })
Write-Output "0.5.1 suite index: $(@($rows).Count) modules (20 from A1-3, 5 from A2-5) -> $OutputPath"
