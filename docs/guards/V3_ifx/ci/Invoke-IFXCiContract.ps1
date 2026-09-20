$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$legacy = 'docs/guards/V3_ifx/ci/Invoke-IFXCiContract.ps1'
$replacement = 'docs/guards/V3_ifx/commands/Invoke-IFXCiContract.ps1'
[Console]::Error.WriteLine("DEPRECATED: $legacy -> $replacement")
& (Join-Path $PSScriptRoot '../commands/Invoke-IFXCiContract.ps1') @args
$invocationSucceeded = $?
$nativeExitCode = Get-Variable -Name LASTEXITCODE -ValueOnly -ErrorAction SilentlyContinue
if ($null -ne $nativeExitCode) { exit [int]$nativeExitCode }
if ($invocationSucceeded) { exit 0 }
exit 1
