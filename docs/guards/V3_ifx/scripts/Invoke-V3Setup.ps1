$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptName = 'Invoke-' + 'V3Setup.ps1'
$replacement = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../../V3/commands/$scriptName"))
$legacyDisplay = 'docs/guards/V3_ifx/scripts/' + $scriptName
$replacementDisplay = 'docs/guards/V3/commands/' + $scriptName
[Console]::Error.WriteLine("DEPRECATED: $legacyDisplay -> $replacementDisplay")
& $replacement @args
exit $LASTEXITCODE
