$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

& (Join-Path $PSScriptRoot '../engine/Invoke-IFXArchitecture.ps1') @args
$invocationSucceeded = $?
$nativeExitCode = Get-Variable -Name LASTEXITCODE -ValueOnly -ErrorAction SilentlyContinue
if ($null -ne $nativeExitCode) { exit [int]$nativeExitCode }
if ($invocationSucceeded) { exit 0 }
exit 1
