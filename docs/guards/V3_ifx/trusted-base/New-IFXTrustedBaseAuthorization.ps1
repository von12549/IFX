[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9][a-z0-9-]*$')][string] $Id,
    [Parameter(Mandatory)][string] $BaseRevision,
    [Parameter(Mandatory)][string] $HeadRevision,
    [Parameter(Mandatory)][string] $PlanPath,
    [Parameter(Mandatory)][string] $DecisionPaths,
    [ValidateSet('change-trusted-base', 'delete', 'move', 'case-rename')][string] $Operation = 'change-trusted-base',
    [string] $ParityContract,
    [string] $AllowedBehaviorDifferencesJson = '[]',
    [string] $SourcePath,
    [string] $DestinationPath,
    [string] $Repository = '.',
    [string] $OutputPath
)

# Maintenance helper for the authorization PR of Plan 06 §12.1: records the exact authorization that the change PR
# (prepared on HeadRevision) will consume. It writes a file for review and never commits.
#  - change-trusted-base: every trusted component change of the prepared revision (needs -ParityContract);
#  - delete, move, case-rename: the tree entries of -SourcePath (and -DestinationPath) and every changed path below them.
# DecisionPaths is comma-separated; AllowedBehaviorDifferencesJson is an array of { mode, reason } objects.
# weaken-policy records are not generated until the base verifier enables them.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'TrustedBase.psm1') -Force
$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repositoryRoot = Get-GuardFullPath $Repository
$base = Resolve-GuardCommit $repositoryRoot $BaseRevision
$head = Resolve-GuardCommit $repositoryRoot $HeadRevision
$record = [ordered]@{
    formatVersion = 1
    id = $Id
    operation = $Operation
    planPath = $PlanPath
    decisionPaths = @($DecisionPaths.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

if ($Operation -eq 'change-trusted-base') {
    if (-not $ParityContract) { throw 'change-trusted-base needs -ParityContract.' }
    $manifestPath = 'docs/guards/V3_ifx/shared/trusted-components.json'
    $baseManifest = Read-GuardJsonBlob $repositoryRoot $base $manifestPath
    if ($null -eq $baseManifest) { throw "Base $base has no trusted component manifest." }
    $headManifest = Read-GuardJsonBlob $repositoryRoot $head $manifestPath
    $tcb = Get-GuardTcbChanges $repositoryRoot $base $head $baseManifest $headManifest
    if ($tcb.Components.Count -eq 0) { throw 'The head revision changes no trusted component; no authorization is needed.' }
    if ($tcb.Gitlinks.Count -gt 0) { throw "Gitlinks cannot be authorized: $($tcb.Gitlinks -join ', ')" }
    $record.changedPaths = @($tcb.Changes | ForEach-Object { $_.Path } | Sort-Object -Unique -CaseSensitive)
    $record.components = @($tcb.Components)
    $record.entries = @($tcb.Changes | Sort-Object Path -CaseSensitive | ForEach-Object { [ordered]@{ path = $_.Path; component = $_.Component; base = $_.Base; head = $_.Head } })
    $record.validationSuite = @(Get-GuardTcbValidationSuite $baseManifest $headManifest $tcb.Components | Sort-Object -Unique -CaseSensitive)
    $record.parityContract = $ParityContract
    $record.allowedBehaviorDifferences = @(ConvertFrom-Json $AllowedBehaviorDifferencesJson -AsHashtable)
    $summary = "$($tcb.Components -join ', ') ($($tcb.Changes.Count) paths)"
}
else {
    if (-not $SourcePath) { throw "$Operation needs -SourcePath." }
    $SourcePath = $SourcePath.Replace('\', '/').TrimEnd('/')
    $sourceBase = Get-GuardTreeEntry $repositoryRoot $base $SourcePath
    if ($null -eq $sourceBase) { throw "Source $SourcePath does not exist in base $base." }
    $record.source = [ordered]@{ path = $SourcePath; base = $sourceBase }
    $roots = @($SourcePath)
    if ($Operation -ne 'delete') {
        if (-not $DestinationPath) { throw "$Operation needs -DestinationPath." }
        $DestinationPath = $DestinationPath.Replace('\', '/').TrimEnd('/')
        $destinationHead = Get-GuardTreeEntry $repositoryRoot $head $DestinationPath
        if ($null -eq $destinationHead) { throw "Destination $DestinationPath does not exist in head $head." }
        $record.destination = [ordered]@{ path = $DestinationPath; base = (Get-GuardTreeEntry $repositoryRoot $base $DestinationPath); head = $destinationHead }
        $roots += $DestinationPath
    }
    $claimed = @(Get-GuardChangedEntries $repositoryRoot $base $head | Where-Object { $entry = $_; @($roots | Where-Object { $entry.Path -ceq $_ -or $entry.Path.StartsWith("$_/", [StringComparison]::Ordinal) }).Count -gt 0 } | Sort-Object Path -CaseSensitive)
    if ($claimed.Count -eq 0) { throw "The head revision does not change $($roots -join ' or ')." }
    $record.changedPaths = @($claimed | ForEach-Object { $_.Path })
    $record.entries = @($claimed | ForEach-Object { [ordered]@{ path = $_.Path; base = $_.Base; head = $_.Head } })
    $summary = "$Operation of $($roots -join ' -> ') ($($claimed.Count) paths)"
}

$destination = if ($OutputPath) { [IO.Path]::GetFullPath($OutputPath) } else { Join-Path $repositoryRoot "$AuthorizationDirectory$Id.json" }
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
[IO.File]::WriteAllText($destination, ($record | ConvertTo-Json -Depth 10) + "`n", [Text.UTF8Encoding]::new($false))
if (-not (Test-GuardJsonSchema -Schema (Join-Path $packageRoot 'contracts/authorization.schema.json') -Path $destination)) { throw 'Authorization does not match its schema.' }
Write-Host "Authorization for $summary written: $destination"
