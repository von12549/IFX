# IFX I2-B amendment A3 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A3-6: the 0.5.2 module-suite index for
# the contract handshake. It starts from the accepted 0.5.1 index (suite-index-051.json: 20 records from A1-3, five from
# A2-5) and replaces the record of the one module A3 changes (ifx-c1-evaluated-reference) with its passing A3-5 record.
# Every record must match the current adapter, policy and version of its module in this tree, so an unchanged module
# that drifted, or a changed module without a new record, fails.
[CmdletBinding()]
param(
    [string]$PredecessorIndexPath = 'artifacts/guards/p10-ifx-i2b/a2-relocation/suite-index-051.json',
    [string]$A35IndexPath = 'artifacts/guards/p10-ifx-i2b/a3-closure/a3-5-suites/index.json',
    [string]$OutputPath = 'artifacts/guards/p10-ifx-i2b/a3-closure/suite-index-052.json'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'IFX050.Tooling.psm1') -Force
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }
$previous = Get-Content (Full $PredecessorIndexPath) -Raw | ConvertFrom-Json -Depth 50
$a35 = Get-Content (Full $A35IndexPath) -Raw | ConvertFrom-Json -Depth 50
if ($previous.kind -cne 'ifx-050a-module-suites' -or $previous.version -cne '0.5.1' -or $previous.summary.passed -ne 25 -or $previous.summary.failed -ne 0) { throw 'The 0.5.1 index is not 25 passing modules.' }
if ($a35.kind -cne 'ifx-052-suite-outcomes' -or $a35.status -cne 'pass' -or @($a35.modules).Count -ne 1) { throw 'The A3-5 record is not one passing module.' }
$changed = @{}; foreach ($m in @($a35.modules)) { $changed[[string]$m.moduleId] = $m }
$rows = foreach ($r in @($previous.modules)) {
    $id = [string]$r.moduleId; $root = Join-Path $PSScriptRoot "modules/$id"
    $adapter = Get-IFX050Sha256 (Join-Path $root 'adapter.ps1'); $policyPath = Join-Path $root 'policy.json'; $policy = if ([IO.File]::Exists($policyPath)) { Get-IFX050Sha256 $policyPath } else { $null }
    $version = (Get-Content (Join-Path $root 'module.json') -Raw | ConvertFrom-Json).version
    if ($changed.ContainsKey($id)) {
        $m = $changed[$id]; $summary = Join-Path (Split-Path -Parent (Full $A35IndexPath)) "$id.summary.json"; $s = Get-Content $summary -Raw | ConvertFrom-Json -Depth 50
        if ($s.adapterSha256 -cne $adapter -or ($policy -and $s.policySha256 -cne $policy) -or $m.status -cne 'pass' -or $m.failed -ne 0 -or $s.version -cne $version) { throw "A3-5 record does not match the current module: $id" }
        [ordered]@{ moduleId = $id; version = $version; status = 'pass'; cases = $m.cases; failed = 0; adapterSha256 = $adapter; policySha256 = $policy; targetCommit = $m.targetCommit; host = $m.host; source = 'A3-5'; summarySha256 = $m.summarySha256 }
    } else {
        if ($r.adapterSha256 -cne $adapter -or ($policy -and $r.policySha256 -cne $policy) -or $r.status -cne 'pass' -or $r.version -cne $version) { throw "The 0.5.1 record does not match the unchanged module: $id" }
        $r
    }
}
if (@($rows | Where-Object { $_.source -ceq 'A3-5' }).Count -ne 1) { throw 'The changed module is not in the 0.5.1 index.' }
Write-IFX050Json (Full $OutputPath) ([ordered]@{ formatVersion = 1; kind = 'ifx-050a-module-suites'; step = 'A3-6'; version = '0.5.2'
    sources = [ordered]@{ predecessor = [ordered]@{ path = $PredecessorIndexPath; sha256 = Get-IFX050Sha256 (Full $PredecessorIndexPath) }; a35 = [ordered]@{ path = $A35IndexPath; sha256 = Get-IFX050Sha256 (Full $A35IndexPath) } }
    summary = [ordered]@{ modules = @($rows).Count; passed = @($rows).Count; failed = 0; fromA13 = @($rows | Where-Object { $_.source -ceq 'A1-3' }).Count; fromA25 = @($rows | Where-Object { $_.source -ceq 'A2-5' }).Count; fromA35 = 1 }
    modules = @($rows) })
Write-Output "0.5.2 suite index: $(@($rows).Count) modules ($(@($rows | Where-Object { $_.source -ceq 'A1-3' }).Count) from A1-3, $(@($rows | Where-Object { $_.source -ceq 'A2-5' }).Count) from A2-5, 1 from A3-5) -> $OutputPath"
