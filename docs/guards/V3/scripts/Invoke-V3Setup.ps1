$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$legacy = 'docs/guards/V3/scripts/Invoke-V3Setup.ps1'
$replacement = 'docs/guards/V3/commands/Invoke-V3Setup.ps1'
[Console]::Error.WriteLine("DEPRECATED: $legacy -> $replacement")
& (Join-Path $PSScriptRoot '../commands/Invoke-V3Setup.ps1') @args
exit $LASTEXITCODE
