# Extracted from docs/guards/candidates/ifx-i2b-051/Test-IFX050CutoverRollback.ps1, its Aggregate branch (IFX I2-B amendment A3,
# ruling R14). The v4-ifx-required job runs it from the trusted base: it passes only when v4-ifx-contract and
# v4-ifx-windows both succeeded. Inputs, JSON and exit codes are those of the original branch (0 pass, 16 blocking).
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('success','failure','cancelled','skipped')][string] $ContractResult,
    [Parameter(Mandatory)][ValidateSet('success','failure','cancelled','skipped')][string] $WindowsResult
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$failures = [Collections.Generic.List[string]]::new()
if ($ContractResult -cne 'success') { $failures.Add("v4-ifx-contract did not succeed: $ContractResult") }
if ($WindowsResult -cne 'success') { $failures.Add("v4-ifx-windows did not succeed: $WindowsResult") }
$result = [ordered]@{ formatVersion = 1; status = $(if ($failures.Count -eq 0) { 'pass' } else { 'fail' }); exitCategory = $(if ($failures.Count -eq 0) { 'success' } else { 'findings-blocking' }); failures = @($failures) }
$json = $result | ConvertTo-Json -Depth 10
if ($failures.Count -gt 0) { [Console]::Error.WriteLine($json); exit 16 }
Write-Output $json
exit 0
