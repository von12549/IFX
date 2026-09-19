[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Preview', 'Apply')][string] $Mode,
    [Parameter(Mandatory)][string] $TargetRoot,
    [Parameter(Mandatory)][string] $SourceDirectory,
    [string[]] $Names = @(),
    [switch] $AcceptAnalysisEvidence
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = [IO.Path]::GetFullPath($TargetRoot)
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$prefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
function Under-Root([string] $value) {
    $path = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($value)) { $value } else { Join-Path $root $value }))
    if (-not $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path must stay under TargetRoot: $value" }
    return $path
}
function Sha([string] $path) {
    if (-not [IO.File]::Exists($path)) { return $null }
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($path))).ToLowerInvariant()
}

$source = Under-Root $SourceDirectory
if (-not [IO.Directory]::Exists($source)) { throw "SourceDirectory does not exist: $source" }
$targets = [ordered]@{
    'ARCHITECTURE.md' = 'stages/analysis/evidence/ARCHITECTURE.md'
    'TECHNICAL.md' = 'stages/analysis/evidence/TECHNICAL.md'
    'legacy-deletion-manifest.json' = 'stages/analysis/evidence/legacy-deletion-manifest.json'
    'CUTOVER-BASELINE.md' = 'stages/analysis/reports/CUTOVER-BASELINE.md'
    'cutover-baseline.json' = 'stages/analysis/reports/cutover-baseline.json'
    'specialized-parity.json' = 'stages/analysis/reports/specialized-parity.json'
}
$selected = @(if ($Names.Count -gt 0) { $Names } else { $targets.Keys | Where-Object { [IO.File]::Exists((Join-Path $source $_)) } })
if ($selected.Count -eq 0) { throw 'No reviewed analysis evidence files were selected or found.' }
foreach ($name in $selected) {
    if (-not $targets.Contains($name)) { throw "Unsupported analysis evidence name: $name" }
    if (-not [IO.File]::Exists((Join-Path $source $name))) { throw "Missing reviewed source: $name" }
}
$changes = @($selected | Sort-Object -Unique | ForEach-Object {
    $sourcePath = Join-Path $source $_
    $targetPath = Join-Path $package $targets[$_]
    [pscustomobject]@{ name = $_; source = [IO.Path]::GetRelativePath($root, $sourcePath).Replace('\','/'); target = [IO.Path]::GetRelativePath($root, $targetPath).Replace('\','/'); sourceSha256 = Sha $sourcePath; targetSha256 = Sha $targetPath; sourcePath = $sourcePath; targetPath = $targetPath }
} | Where-Object { $_.sourceSha256 -cne $_.targetSha256 })
if ($changes.Count -eq 0) { Write-Host 'Analysis evidence is already current.'; exit 0 }
foreach ($change in $changes) { Write-Host "$Mode $($change.name): $($change.targetSha256) -> $($change.sourceSha256)" }
if ($Mode -eq 'Preview') { Write-Host "Previewed $($changes.Count) reviewed analysis evidence change(s); no authority was written."; exit 0 }
if (-not $AcceptAnalysisEvidence) { throw 'Apply requires -AcceptAnalysisEvidence after reviewing Preview.' }
foreach ($change in $changes) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($change.targetPath))
    [IO.File]::WriteAllBytes($change.targetPath, [IO.File]::ReadAllBytes($change.sourcePath))
}
Write-Host "Applied $($changes.Count) reviewed analysis evidence change(s)."
