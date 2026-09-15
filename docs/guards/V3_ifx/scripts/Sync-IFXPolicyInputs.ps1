[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Validate', 'Generate', 'Check')][string] $Mode,
    [string] $TargetRoot,
    [string] $PackageRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$packageRoot = if ($PackageRoot) { [IO.Path]::GetFullPath($PackageRoot) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')) }
$repositoryRoot = if ($TargetRoot) { [IO.Path]::GetFullPath($TargetRoot) } else { [IO.Path]::GetFullPath((Join-Path $packageRoot '../../..')) }
$registryPath = Join-Path $packageRoot 'policy/authorities.json'
$registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$utf8 = [Text.UTF8Encoding]::new($false)

function Resolve-ContainedPath {
    param([string] $Root, [string] $Relative, [string] $Label)
    if ([IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)') { throw "Unsafe $Label path: $Relative" }
    $resolved = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
    $prefix = $Root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "$Label escapes its root: $Relative" }
    return $resolved
}

function ConvertTo-Lf([string] $Text) { return $Text.Replace("`r`n", "`n").Replace("`r", "`n") }
function Get-CanonicalText([string] $Path) { return ConvertTo-Lf ([IO.File]::ReadAllText($Path)) }
function Get-Sha256([string] $Text) {
    $bytes = $utf8.GetBytes($Text)
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}
function ConvertTo-CanonicalJson([object] $Value) { return (ConvertTo-Lf (($Value | ConvertTo-Json -Depth 100))) + "`n" }

$expected = [ordered]@{}
foreach ($binding in @($registry.g04Bindings)) {
    $source = Resolve-ContainedPath $repositoryRoot $binding.source "authority source"
    $target = Resolve-ContainedPath $packageRoot $binding.target "projection target"
    if (-not [IO.File]::Exists($source)) { throw "Authority source is missing: $($binding.source)" }
    $expected[$target] = Get-CanonicalText $source
}

foreach ($projection in @($registry.projections)) {
    $source = Resolve-ContainedPath $repositoryRoot $projection.source "authority source"
    $target = Resolve-ContainedPath $packageRoot $projection.target "projection target"
    if (-not [IO.File]::Exists($source)) { throw "Authority source is missing: $($projection.source)" }
    switch ($projection.transform) {
        'copy-lf' { $expected[$target] = Get-CanonicalText $source }
        'g03-governance' {
            $document = Get-CanonicalText $source | ConvertFrom-Json -AsHashtable -Depth 100
            $catalogTarget = Resolve-ContainedPath $packageRoot 'policy/g03/catalog.json' 'G03 catalog target'
            $catalogText = if ($expected.Contains($catalogTarget)) { $expected[$catalogTarget] } else { Get-CanonicalText $catalogTarget }
            $document.source = 'g03/catalog.json'
            $document.catalogSha256 = Get-Sha256 $catalogText
            $expected[$target] = ConvertTo-CanonicalJson $document
        }
        'g04-runtime' {
            $document = Get-CanonicalText $source | ConvertFrom-Json -AsHashtable -Depth 100
            foreach ($binding in @($registry.g04Bindings)) {
                $bindingTarget = Resolve-ContainedPath $packageRoot $binding.target "G04 binding target"
                $relative = [IO.Path]::GetRelativePath((Join-Path $packageRoot 'policy'), $bindingTarget).Replace('\', '/')
                $document.bindings[$binding.key].path = $relative
                $document.bindings[$binding.key].sha256 = Get-Sha256 $expected[$bindingTarget]
            }
            $expected[$target] = ConvertTo-CanonicalJson $document
        }
        default { throw "Unknown projection transform: $($projection.transform)" }
    }
}

if ($Mode -eq 'Validate') {
    Write-Host "IFX authority registry is valid: $($expected.Count) projections."
    exit 0
}

$differences = [Collections.Generic.List[string]]::new()
foreach ($entry in $expected.GetEnumerator()) {
    if (-not [IO.File]::Exists($entry.Key)) {
        $differences.Add([IO.Path]::GetRelativePath($packageRoot, $entry.Key).Replace('\', '/'))
        if ($Mode -eq 'Generate') { [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($entry.Key)) | Out-Null; [IO.File]::WriteAllText($entry.Key, $entry.Value, $utf8) }
        continue
    }
    if ((Get-CanonicalText $entry.Key) -cne $entry.Value) {
        $differences.Add([IO.Path]::GetRelativePath($packageRoot, $entry.Key).Replace('\', '/'))
        if ($Mode -eq 'Generate') { [IO.File]::WriteAllText($entry.Key, $entry.Value, $utf8) }
    }
}

if ($Mode -eq 'Check' -and $differences.Count -gt 0) { throw "IFX policy projections are stale: $($differences -join ', ')" }
Write-Host "IFX policy projection $Mode passed ($($expected.Count) files; changed: $($differences.Count))."
