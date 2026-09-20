[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $ProfileDirectory,
    [Parameter(Mandatory)][string] $TargetRoot,
    [string] $PlanPath,
    [string[]] $PlannedPaths = @(),
    [string] $ReportPath,
    [string] $OutputDirectory,
    [string] $GenerationRoot
)

$ErrorActionPreference = 'Stop'
if ([bool] $PlanPath -eq ($PlannedPaths.Count -gt 0)) { throw 'Provide exactly one of PlanPath or PlannedPaths.' }
$preArgs = @{ Mode = 'Pre'; ProfileDirectory = $ProfileDirectory; TargetRoot = $TargetRoot }
if ($PlanPath) { $preArgs.PlanPath = $PlanPath } else { $preArgs.PlannedPaths = $PlannedPaths }
if ($ReportPath) { $preArgs.ReportPath = $ReportPath }
if ($OutputDirectory) { $preArgs.OutputDirectory = $OutputDirectory }
if ($GenerationRoot) { $preArgs.GenerationRoot = $GenerationRoot }
& (Join-Path $PSScriptRoot '../commands/Invoke-V3.ps1') @preArgs
exit $LASTEXITCODE
