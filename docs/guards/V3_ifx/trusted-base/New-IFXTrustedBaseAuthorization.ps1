[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9-]*$')][string] $Id,
    [Parameter(Mandatory)][string] $BaseRevision,
    [Parameter(Mandatory)][string] $HeadRevision,
    [Parameter(Mandatory)][string] $PlanPath,
    [Parameter(Mandatory)][string] $DecisionPaths,
    [Parameter(Mandatory)][string] $ParityContract,
    [string] $AllowedBehaviorDifferencesJson = '[]',
    [string] $Repository = '.',
    [string] $OutputPath
)

# Maintenance helper for the authorization PR of Plan 06 §12.1: records the exact change-trusted-base authorization
# that the change PR (prepared on HeadRevision) will consume. It writes a file for review and never commits.
# DecisionPaths is comma-separated; AllowedBehaviorDifferencesJson is an array of { mode, reason } objects.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'TrustedBase.psm1') -Force
$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repositoryRoot = Get-GuardFullPath $Repository
$base = Resolve-GuardCommit $repositoryRoot $BaseRevision
$head = Resolve-GuardCommit $repositoryRoot $HeadRevision
$manifestPath = 'docs/guards/V3_ifx/shared/trusted-components.json'
$baseManifest = Read-GuardJsonBlob $repositoryRoot $base $manifestPath
if ($null -eq $baseManifest) { throw "Base $base has no trusted component manifest." }
$headManifest = Read-GuardJsonBlob $repositoryRoot $head $manifestPath
$tcb = Get-GuardTcbChanges $repositoryRoot $base $head $baseManifest $headManifest
if ($tcb.Components.Count -eq 0) { throw 'The head revision changes no trusted component; no authorization is needed.' }
if ($tcb.Gitlinks.Count -gt 0) { throw "Gitlinks cannot be authorized: $($tcb.Gitlinks -join ', ')" }

$record = [ordered]@{
    formatVersion = 1
    id = $Id
    operation = 'change-trusted-base'
    planPath = $PlanPath
    decisionPaths = @($DecisionPaths.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    changedPaths = @($tcb.Changes | ForEach-Object { $_.Path } | Sort-Object -Unique -CaseSensitive)
    components = @($tcb.Components)
    entries = @($tcb.Changes | Sort-Object Path -CaseSensitive | ForEach-Object { [ordered]@{ path = $_.Path; component = $_.Component; base = $_.Base; head = $_.Head } })
    validationSuite = @(Get-GuardTcbValidationSuite $baseManifest $headManifest $tcb.Components | Sort-Object -Unique -CaseSensitive)
    parityContract = $ParityContract
    allowedBehaviorDifferences = @(ConvertFrom-Json $AllowedBehaviorDifferencesJson -AsHashtable)
}
$destination = if ($OutputPath) { [IO.Path]::GetFullPath($OutputPath) } else { Join-Path $repositoryRoot "$AuthorizationDirectory$Id.json" }
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
[IO.File]::WriteAllText($destination, ($record | ConvertTo-Json -Depth 10) + "`n", [Text.UTF8Encoding]::new($false))
if (-not (Test-Json -Path $destination -SchemaFile (Join-Path $packageRoot 'contracts/authorization.schema.json') -ErrorAction Stop)) { throw 'Authorization does not match its schema.' }
Write-Host "Authorization for $($tcb.Components -join ', ') ($($tcb.Changes.Count) paths) written: $destination"
