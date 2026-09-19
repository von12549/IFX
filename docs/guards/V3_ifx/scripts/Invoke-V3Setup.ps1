$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptName = 'Invoke-' + 'V3Setup.ps1'
$replacement = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../../V3/scripts/$scriptName"))
$legacyDisplay = 'docs/guards/V3_ifx/scripts/' + $scriptName
$replacementDisplay = 'docs/guards/V3/scripts/' + $scriptName
[Console]::Error.WriteLine("DEPRECATED: $legacyDisplay -> $replacementDisplay")
& $replacement @args
exit $LASTEXITCODE
