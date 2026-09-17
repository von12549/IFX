[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $TargetRoot,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string] $BaseSha,
    [Parameter(Mandatory)][string] $HeadRevision,
    [string] $ReportPath = 'artifacts/guards/v3-ifx/trusted-base/change-scope.json',
    [string] $GitHubOutput
)

# Base-owned classification of the verified changed set (Plan 06 D28), used to decide which gate work a pull request can
# inherit from its base instead of repeating:
#  1. the changed set is the NUL-separated raw diff without rename detection from the verified merge base to the explicit
#     head commit, exactly as the protected change verifier reads it (§12.3);
#  2. scope `records-and-plans` means every changed path is a formal plan document, an authorization record or a decision
#     record, so no gate input outside this package's own review artifacts changed;
#  3. every other outcome, including an empty changed set, a path this script does not recognize, or any failure, is
#     `full`, so gate work is repeated. The classification never widens what a gate checks.
# The script must run from the base commit; head supplies Git objects only, never the algorithm or the path list.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'TrustedBase.psm1') -Force
$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$baseRepository = Get-GuardFullPath (Join-Path $packageRoot '../../..')
$target = Get-GuardFullPath $TargetRoot
$report = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $target $ReportPath }))
$result = [ordered]@{
    formatVersion = 1
    check = 'change-scope'
    scope = 'full'
    baseSha = $BaseSha
    mergeBase = $null
    headSha = $null
    protectionSha256 = $null
    recordPrefixes = @()
    changedPaths = @()
    unrecognizedPaths = @()
    reason = $null
}

try {
    $baseHead = Resolve-GuardCommit $baseRepository 'HEAD'
    if ($baseHead -ne $BaseSha) { throw "The classification must run from the base commit $BaseSha, not $baseHead." }
    $headSha = Resolve-GuardCommit $target $HeadRevision
    $result.headSha = $headSha
    $mergeBase = @(Invoke-GuardGit $target @('merge-base', $BaseSha, $headSha) -AllowFailure)
    if ($LASTEXITCODE -ne 0 -or $mergeBase.Count -ne 1 -or $mergeBase[0] -notmatch '^[0-9a-f]{40}$') { throw 'Base and head have no single merge base; fetch complete history.' }
    $mergeBase = $mergeBase[0]
    $result.mergeBase = $mergeBase

    $protection = Read-GuardProtection $packageRoot
    $result.protectionSha256 = $protection.Sha256
    $directory = $protection.AuthorizationDirectory
    if ($directory -and $directory -cne $AuthorizationDirectory) { throw "The Diff protection authorizationDirectory $directory differs from the trusted base protocol directory $AuthorizationDirectory." }
    # Review artifacts of this plan: formal plan pairs, authorization records and decision records. Nothing here is a gate
    # input: gates read policy, profiles, engines, tests, fixtures and the target's own sources.
    $prefixes = [string[]] @(
        'docs/guards/plans/',
        $AuthorizationDirectory,
        'docs/guards/V3_ifx/decisions/history/'
    )
    $result.recordPrefixes = $prefixes

    $entries = @(Get-GuardChangedEntries $target $mergeBase $headSha)
    $paths = [string[]] @($entries | ForEach-Object { $_.Path } | Sort-Object -Unique -CaseSensitive)
    $result.changedPaths = $paths
    if ($paths.Count -eq 0) { throw 'The changed set is empty; base/head inputs may be wrong or history may be incomplete.' }
    $unrecognized = [string[]] @($paths | Where-Object { $path = $_; @($prefixes | Where-Object { $path.StartsWith($_, [StringComparison]::Ordinal) }).Count -eq 0 })
    $result.unrecognizedPaths = $unrecognized
    if ($unrecognized.Count -eq 0) {
        $result.scope = 'records-and-plans'
        $result.reason = "All $($paths.Count) changed path(s) are formal plan documents, authorization records or decision records."
    }
    else {
        $result.reason = "$($unrecognized.Count) changed path(s) are gate inputs or unrecognized: $(($unrecognized | Select-Object -First 5) -join ', ')."
    }
}
catch {
    $result.scope = 'full'
    $result.reason = "Classification failed, so every gate repeats its work: $($_.Exception.Message)"
}

[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($report))
[IO.File]::WriteAllText($report, ($result | ConvertTo-Json -Depth 10) + "`n", [Text.UTF8Encoding]::new($false))
if (-not (Test-GuardJsonSchema -Schema (Join-Path $packageRoot 'contracts/change-scope.schema.json') -Path $report)) {
    throw 'The change scope report does not match its schema.'
}
if ($GitHubOutput) { [IO.File]::AppendAllText($GitHubOutput, "scope=$($result.scope)`n") }
Write-Host "Change scope $($result.scope): $($result.reason) Report: $report"
