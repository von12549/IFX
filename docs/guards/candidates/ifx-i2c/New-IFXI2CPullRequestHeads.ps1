# IFX I2-C (Plan 20261001-v4-ifx-i2c-main-promotion) step C2, reused by C3 and C5-C7: build one pull request head of
# pr-spec.json on a given base commit in a disposable clone, then check it byte for byte.
#  -Kind change: the set's copied paths (from the reviewed development-branch commit), its authored files (pr/<set>/) and,
#    with -ConsumeRecords, the deletion of the set's authorization records, which must then exist at the base.
#  -Kind authorization: only the generated records from -RecordsDirectory and the authorization plan pair (pr/<set>a/).
# The changed set must equal the expected set exactly; every copied blob must equal the source blob and every authored or
# generated blob must equal its file. Nothing is pushed.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Clone,
    [Parameter(Mandatory)][ValidatePattern('^P[0-9]$')][string] $Set,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string] $BaseCommit,
    [ValidateSet('change', 'authorization')][string] $Kind = 'change',
    [switch] $ConsumeRecords,
    [string] $RecordsDirectory,
    [string] $Branch,
    [string] $SpecPath = (Join-Path $PSScriptRoot 'pr-spec.json'),
    [string] $SourceRepository = (Join-Path $PSScriptRoot '../../../..'),
    [string[]] $GitIdentity = @()
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'IFXI2C.Common.psm1') -Force
$spec = Get-Content -Raw -LiteralPath $SpecPath | ConvertFrom-Json -Depth 20
$entry = @($spec.sets | Where-Object id -CEQ $Set)
Assert-IFXI2C ($entry.Count -eq 1) "Unknown set $Set."
$entry = $entry[0]
$clonePath = [IO.Path]::GetFullPath($Clone)
$source = [IO.Path]::GetFullPath($SourceRepository)
$authorizationDirectory = [string]$spec.authorizationDirectory
function CloneGit([string[]] $Arguments) { return Invoke-IFXI2CGit $clonePath (@($GitIdentity) + $Arguments) }

$records = @($entry.authorizations | ForEach-Object { "$authorizationDirectory/$($_.id).json" })
$authoredRoot = Join-Path $PSScriptRoot "pr/$Set"
$authored = @($entry.authored)
$copy = @($entry.copy)
$deleted = @()
$planId = [IO.Path]::GetFileName([string]$entry.plan).Replace('.plan.json', '')
if ($Kind -eq 'authorization') {
    Assert-IFXI2C ($records.Count -gt 0) "Set $Set has no authorizations."
    Assert-IFXI2C ([bool]$RecordsDirectory) '-RecordsDirectory is required for an authorization head.'
    $authoredRoot = Join-Path $PSScriptRoot "pr/${Set}a"
    $authored = @("docs/guards/plans/$planId-authorization.md", "docs/guards/plans/$planId-authorization.plan.json")
    $copy = @()
}
elseif ($ConsumeRecords) { $deleted = $records }
$branchName = if ($Branch) { $Branch } elseif ($Kind -eq 'authorization') { "$($entry.branch)-authorization" } else { [string]$entry.branch }

[void](CloneGit @('checkout', '-q', '-f', '-B', $branchName, $BaseCommit))
[void](CloneGit @('clean', '-q', '-fdx'))
foreach ($path in $deleted) {
    [void](CloneGit @('cat-file', '-e', "${BaseCommit}:$path"))
    [void](CloneGit @('rm', '-q', '--', $path))
}
if ($copy.Count -gt 0) { [void](CloneGit (@('restore', "--source=$($spec.sourceCommit)", '--staged', '--worktree', '--') + $copy)) }
foreach ($path in $authored) {
    $from = Join-Path $authoredRoot $path
    Assert-IFXI2C ([IO.File]::Exists($from)) "Authored file is missing: pr/$([IO.Path]::GetFileName($authoredRoot))/$path"
    $to = Join-Path $clonePath $path
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $to))
    [IO.File]::Copy($from, $to, $true)
}
$generated = @()
if ($Kind -eq 'authorization') {
    foreach ($path in $records) {
        $from = Join-Path ([IO.Path]::GetFullPath($RecordsDirectory)) ([IO.Path]::GetFileName($path))
        Assert-IFXI2C ([IO.File]::Exists($from)) "Generated record is missing: $from"
        [IO.File]::Copy($from, (Join-Path $clonePath $path), $true)
        $generated += [ordered]@{ path = $path; file = $from }
    }
}
[void](CloneGit @('add', '-A'))
$message = if ($Kind -eq 'authorization') { "guards(v3): authorize $($entry.branch.Replace('codex/i2c-', '')) ($Set, I2-C)" } else { "$($entry.message) ($Set, I2-C)" }
[void](CloneGit @('commit', '-q', '-m', $message, '-m', "Plan: docs/guards/plans/$planId$(if ($Kind -eq 'authorization') { '-authorization' }).plan.json (IFX I2-C, 20261001-v4-ifx-i2c-main-promotion)", '-m', 'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'))
$head = (CloneGit @('rev-parse', 'HEAD'))[0].Trim()

# ---- byte checks
$diffLines = CloneGit @('diff', '--name-status', '--no-renames', $BaseCommit, $head)
$changed = @(foreach ($line in $diffLines) { $parts = ([string]$line).Split("`t"); [ordered]@{ status = $parts[0]; path = $parts[1] } })
$expected = @(@($copy) + @($authored) + @($records | Where-Object { $Kind -eq 'authorization' }) + @($deleted) | Sort-Object -Unique)
$actual = @($changed | ForEach-Object path | Sort-Object -Unique)
Assert-IFXI2C (($actual -join "`n") -ceq ($expected -join "`n")) "Changed set differs from the spec.`n expected: $($expected -join ', ')`n actual:   $($actual -join ', ')"
foreach ($path in $deleted) { Assert-IFXI2C ((@($changed | Where-Object { $_.path -ceq $path })[0].status) -ceq 'D') "Record is not deleted: $path" }
$blobs = [ordered]@{}
foreach ($path in $copy) {
    $want = (Invoke-IFXI2CGit $source @('rev-parse', "$($spec.sourceCommit):$path"))[0].Trim()
    $have = (CloneGit @('rev-parse', "${head}:$path"))[0].Trim()
    Assert-IFXI2C ($want -ceq $have) "Copied blob differs from the source commit: $path"
    $blobs[$path] = [ordered]@{ blob = $have; origin = 'source-commit' }
}
foreach ($path in @($authored) + @($generated | ForEach-Object path)) {
    $file = if ($path -in $authored) { Join-Path $authoredRoot $path } else { @($generated | Where-Object path -CEQ $path)[0].file }
    $want = (CloneGit @('hash-object', "--path=$path", $file))[0].Trim()
    $raw = (CloneGit @('hash-object', '--no-filters', $file))[0].Trim()
    $have = (CloneGit @('rev-parse', "${head}:$path"))[0].Trim()
    Assert-IFXI2C ($want -ceq $have -and $raw -ceq $have) "Authored blob differs from its file (or needs normalization): $path"
    $blobs[$path] = [ordered]@{ blob = $have; origin = $(if ($path -in $authored) { 'authored' } else { 'generated' }) }
}
[ordered]@{
    set = $Set; kind = $Kind; consumesRecords = [bool]$ConsumeRecords; branch = $branchName
    base = $BaseCommit; head = $head; changed = $changed; blobs = $blobs
} | ConvertTo-Json -Depth 10 -Compress
