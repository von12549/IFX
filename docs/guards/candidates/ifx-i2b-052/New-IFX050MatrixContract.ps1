# IFX I2-B amendment A1 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A1-4: derive the 0.5.0-a independent
# matrix contract from the accepted I1 contract (candidates/ifx-rebind-116/matrix-contract-116.json, unchanged). Rules,
# claims, zero strategies and rule overrides carry over (0.5.0-a keeps every rule); the inventory projection and the
# adapter path and hash of each module changed by the A1-2 specification are rebound. Documented deviations in
# -Adjustments (module id -> property -> value) are applied last and listed in the contract.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InventoryPath,
    [string]$SourceContractPath = 'docs/guards/candidates/ifx-rebind-116/matrix-contract-116.json',
    [string]$OutputPath = 'docs/guards/candidates/ifx-i2b-052/matrix-contract-050.json',
    [string]$AdjustmentsPath = 'docs/guards/candidates/ifx-i2b-052/matrix-adjustments-050.json'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'IFX050.Tooling.psm1') -Force
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
function Full([string]$Path) { if ([IO.Path]::IsPathFullyQualified($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $repo $Path)) } }
$inventory = Get-Content (Full $InventoryPath) -Raw | ConvertFrom-Json -Depth 100
if ($inventory.scope -cne 'ifx-050a-source-module-claim-inventory') { throw 'Not a 0.5.0-a inventory.' }
$contract = Get-Content (Full $SourceContractPath) -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$projection = [ordered]@{
    modules = @($inventory.modules | Sort-Object ordinal | ForEach-Object { [ordered]@{ ordinal = $_.ordinal; id = $_.id; stage = $_.stage; sourcePath = $_.sourcePath; adapterSha256 = $_.adapterSha256 } })
    rules = @($inventory.rules | Sort-Object ordinal | ForEach-Object { [ordered]@{ ordinal = $_.ordinal; moduleOrdinal = $_.moduleOrdinal; moduleId = $_.moduleId; stage = $_.stage; ruleId = $_.ruleId; claimId = $_.claimId; severity = $_.severity; minimumMatches = $_.minimumMatches } })
}
$out = [ordered]@{}
foreach ($k in $contract.Keys) { $out[$k] = $contract[$k] }
$out.id = 'ifx-050a-independent-matrix-contract'
$out.derivedFrom = [ordered]@{ path = $SourceContractPath; sha256 = Get-IFX050PinSha256 (Full $SourceContractPath) }
$out.inventoryProjectionSha256 = Get-IFX050Sha256Text (($projection | ConvertTo-Json -Depth 20 -Compress).Replace("`r`n", "`n"))
foreach ($m in $out.modules) {
    $row = @($inventory.modules | Where-Object { $_.id -ceq $m.id })[0]
    if ($row.disposition -ceq 'changed') { $m.adapterPath = "$($row.sourcePath)/adapter.ps1"; $m.adapterSha256 = $row.adapterSha256 }
}
$applied = [Collections.Generic.List[object]]::new()
$adjust = Full $AdjustmentsPath
if (Test-Path -LiteralPath $adjust) {
    $adjustments = Get-Content $adjust -Raw | ConvertFrom-Json -AsHashtable -Depth 30
    foreach ($a in @($adjustments.modules)) {
        $m = @($out.modules | Where-Object { $_.id -ceq $a.id }); if ($m.Count -ne 1) { throw "Adjustment for unknown module: $($a.id)" }
        foreach ($k in $a.set.Keys) { $m[0][$k] = $a.set[$k] }
        $applied.Add([ordered]@{ id = $a.id; set = $a.set; reason = $a.reason })
    }
    foreach ($a in @($adjustments.ruleOverrides)) {
        $o = @($out.ruleOverrides | Where-Object { $_.moduleId -ceq $a.moduleId -and $_.ruleId -ceq $a.ruleId })
        if ($o.Count -eq 1) { foreach ($k in $a.set.Keys) { $o[0][$k] = $a.set[$k] } }
        else { $n = [ordered]@{ moduleId = $a.moduleId; ruleId = $a.ruleId }; foreach ($k in $a.set.Keys) { $n[$k] = $a.set[$k] }; $out.ruleOverrides = @($out.ruleOverrides) + @($n) }
        $applied.Add([ordered]@{ id = "$($a.moduleId)/$($a.ruleId)"; set = $a.set; reason = $a.reason })
    }
}
$out.adjustments = @($applied.ToArray())
Write-IFX050Json (Full $OutputPath) $out
"matrix contract: $(Full $OutputPath) ($($applied.Count) adjustments)"
