[CmdletBinding()]
param(
    [string] $TargetRoot,
    [string] $WorkflowPath = '.github/workflows/v3-ifx-guardrails.yml',
    [string] $RequiredChecksPath,
    [string] $RulesetJsonPath,
    [switch] $Remote,
    [string] $Repository,
    [string] $ReportPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$legacy = 'docs/guards/V3_ifx/ci/Invoke-IFXCiContract.ps1'
$replacement = 'docs/guards/V3_ifx/commands/Invoke-IFXCiContract.ps1'
[Console]::Error.WriteLine("DEPRECATED: $legacy -> $replacement")
$root = if ($TargetRoot) { [IO.Path]::GetFullPath($TargetRoot) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..')) }
$workflow = if ([IO.Path]::IsPathRooted($WorkflowPath)) { $WorkflowPath } else { Join-Path $root $WorkflowPath }
if ([IO.File]::Exists($workflow)) {
    $legacyDispatcher = @([IO.File]::ReadAllLines($workflow) | Where-Object { $_ -match '\./docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails\.ps1' })
    if ($legacyDispatcher.Count -gt 0) {
        [Console]::Error.WriteLine('FAIL trusted-base-no-head-dispatcher:v3-historical-integrity: jobs must not run the legacy head dispatcher in place; use the trusted base runner')
        exit 1
    }
}
& (Join-Path $PSScriptRoot '../commands/Invoke-IFXCiContract.ps1') @PSBoundParameters
$invocationSucceeded = $?
$nativeExitCode = Get-Variable -Name LASTEXITCODE -ValueOnly -ErrorAction SilentlyContinue
if ($null -ne $nativeExitCode) { exit [int]$nativeExitCode }
if ($invocationSucceeded) { exit 0 }
exit 1
