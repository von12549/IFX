[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $ProfileDirectory,
    [Parameter(Mandatory)][string] $TargetRoot,
    [Parameter(Mandatory)][string] $PlanPath
)

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '../scripts/Invoke-V3.ps1') -Mode Pre -ProfileDirectory $ProfileDirectory -TargetRoot $TargetRoot -PlanPath $PlanPath
exit $LASTEXITCODE
