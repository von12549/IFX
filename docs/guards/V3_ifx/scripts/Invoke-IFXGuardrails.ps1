$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$legacy = 'docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1'
$replacement = 'docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1'
[Console]::Error.WriteLine("DEPRECATED: $legacy -> $replacement")
& (Join-Path $PSScriptRoot '../commands/Invoke-IFXGuardrails.ps1') @args
exit $LASTEXITCODE
