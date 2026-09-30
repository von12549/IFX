# IFX I2-B amendment A2 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A2-1: the relocation inventory of the
# producers moved to docs/guards/v4-adoption/producers (0.5.0-b, bundle 0.5.1). For every file in relocation-spec.json it
# records the origin identity (raw SHA-256, LF-normalized SHA-256, Git blob at HEAD, lines) and scans every PowerShell
# origin for file references. A reference that resolves into docs/guards (V3, V3_ifx or the lab tree) must be a relocated
# file, a declared non-relocated file or an explicit literal classification; anything else fails as an unlisted read.
# -Check re-derives the inventory and compares it with the committed one.
[CmdletBinding()]
param(
    [string]$SpecPath = (Join-Path $PSScriptRoot 'relocation-spec.json'),
    [string]$OutPath = (Join-Path $PSScriptRoot 'relocation-inventory.json'),
    [switch]$Check
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
function Rel([string]$Path) { [IO.Path]::GetRelativePath($repo, $Path).Replace('\', '/') }
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function LfHash([string]$Path) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($Path).ReplaceLineEndings("`n")))).ToLowerInvariant() }
function Write-Json([string]$Path, $Value) { [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 20).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false)) }

$spec = Get-Content -LiteralPath $SpecPath -Raw | ConvertFrom-Json -Depth 20
$origins = @{}; foreach ($f in @($spec.files)) { $origins[[string]$f.origin] = $f }
$declared = @{}; foreach ($n in @($spec.notRelocated)) { $declared[[string]$n.path] = $n }
$classified = @{}; foreach ($c in @($spec.literalClassifications)) { $classified["$($c.in)|$($c.literal)"] = $c }
$head = (& git -C $repo rev-parse HEAD).Trim()
# Top-level Target entries (docs excluded: docs/guards references are resolved as package reads) and the declared
# evidence-output prefixes of the producers' run directories.
$targetTop = @(& git -C $repo ls-tree --name-only HEAD | Where-Object { $_ -cne 'docs' })
$outputPrefixes = @($spec.outputRelativePrefixes)

# A literal path reference with the variable it is joined to (Join-Path $var 'x' / "x"), or a bare docs/guards literal.
$joinPattern = [regex]'Join-Path\s+\$(?<base>[A-Za-z]+)\s+(?<q>[''"])(?<lit>[^''"]+)\k<q>'
$barePattern = [regex]'(?<q>[''"])(?<lit>docs/guards/[^''"]+)\k<q>'
$filePattern = [regex]'(?<q>[''"])(?<lit>[A-Za-z0-9_./-]+\.(?:ps1|psm1|json|sln|csproj|dll))\k<q>'
$unlisted = [Collections.Generic.List[object]]::new()
$rows = foreach ($f in @($spec.files)) {
    $path = Join-Path $repo ([string]$f.origin)
    if (-not [IO.File]::Exists($path)) { throw "Origin is missing: $($f.origin)" }
    $blob = (& git -C $repo rev-parse "HEAD:$($f.origin)" 2>$null); if ($LASTEXITCODE -ne 0) { throw "Origin is not tracked at HEAD: $($f.origin)" }
    $refs = [Collections.Generic.List[object]]::new()
    if ([IO.Path]::GetExtension($path) -ceq '.ps1') {
        $text = [IO.File]::ReadAllText($path); $dir = [IO.Path]::GetDirectoryName($path); $seen = @{}
        $found = [Collections.Generic.List[object]]::new()
        foreach ($m in $joinPattern.Matches($text)) { $found.Add(@{ base = $m.Groups['base'].Value; lit = $m.Groups['lit'].Value }) }
        foreach ($m in $barePattern.Matches($text)) { $found.Add(@{ base = 'repo'; lit = $m.Groups['lit'].Value }) }
        foreach ($m in $filePattern.Matches($text)) { $found.Add(@{ base = '?'; lit = $m.Groups['lit'].Value }) }
        foreach ($r in $found) {
            $key = "$($r.base)|$($r.lit)"; if ($seen.ContainsKey($key) -or ($r.base -ceq '?' -and @($found | Where-Object { $_.lit -ceq $r.lit -and $_.base -cne '?' }).Count)) { continue }; $seen[$key] = $true
            $resolved = switch ($r.base) {
                'PSScriptRoot' { Rel ([IO.Path]::GetFullPath((Join-Path $dir $r.lit))) }
                'scriptRoot' { Rel ([IO.Path]::GetFullPath((Join-Path (Join-Path $dir 'scripts') $r.lit))) }
                default { if ($r.lit.StartsWith('docs/guards/', [StringComparison]::OrdinalIgnoreCase)) { $r.lit } else { $null } }
            }
            $first = $r.lit.Split('/')[0]
            $class = if ($null -eq $resolved) {
                if ($classified.ContainsKey("$($f.origin)|$($r.lit)")) { 'classified' }
                elseif ($r.base -cne '?') { 'target-or-output' }
                elseif ($targetTop -ccontains $first -or ($first -ceq 'docs' -and -not $r.lit.StartsWith('docs/guards/', [StringComparison]::OrdinalIgnoreCase))) { 'target-input' }
                elseif (@($outputPrefixes | Where-Object { $r.lit.StartsWith($_, [StringComparison]::Ordinal) }).Count) { 'output-relative' }
                else { 'unresolved-literal' }
            } elseif (-not $resolved.StartsWith('docs/guards/', [StringComparison]::OrdinalIgnoreCase)) {
                if ($r.lit -match '^(\.\./)+\.?\.?$') { 'repository-root-discovery' } else { 'target-or-output' }
            } elseif ($origins.ContainsKey($resolved)) { 'relocated' }
            elseif ($declared.ContainsKey($resolved)) { 'declared-not-relocated' }
            elseif (@($origins.Keys | Where-Object { $_.StartsWith("$resolved/", [StringComparison]::Ordinal) }).Count) { 'relocated-directory' }
            elseif ($classified.ContainsKey("$($f.origin)|$($r.lit)")) { 'classified' }
            else { 'unlisted-package-read' }
            if ($class -in @('unlisted-package-read', 'unresolved-literal')) { $unlisted.Add([ordered]@{ origin = $f.origin; base = $r.base; literal = $r.lit; resolved = $resolved; class = $class }) }
            $refs.Add([ordered]@{ base = $r.base; literal = $r.lit; resolved = $resolved; class = $class })
        }
    }
    [ordered]@{ origin = $f.origin; destination = "$($spec.destinationRoot)/$($f.destination)"; kind = $f.kind; gates = @($f.gates)
        sha256 = Hash $path; lfSha256 = LfHash $path; gitBlob = $blob.Trim(); lines = @([IO.File]::ReadAllLines($path)).Count; references = @($refs) }
}
$inventory = [ordered]@{ formatVersion = 1; kind = 'ifx-051-producer-relocation-inventory'; specSha256 = LfHash $SpecPath; destinationRoot = $spec.destinationRoot
    fileCount = @($rows).Count; v3FileCount = @($rows | Where-Object { $_.kind -like 'v3-*' }).Count; v3Lines = (@($rows | Where-Object { $_.kind -ceq 'v3-gate' } | ForEach-Object { [int]$_.lines }) | Measure-Object -Sum).Sum
    files = @($rows); unlistedReads = @($unlisted); status = $(if ($unlisted.Count -eq 0) { 'pass' } else { 'fail' }) }
if ($Check) {
    $committed = Get-Content -LiteralPath $OutPath -Raw | ConvertFrom-Json -Depth 20 | ConvertTo-Json -Depth 20 -Compress
    $derived = $inventory | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20 | ConvertTo-Json -Depth 20 -Compress
    if ($committed -cne $derived) { throw 'Committed relocation inventory differs from the re-derived inventory.' }
    Write-Output "Relocation inventory re-derived: equal ($($inventory.fileCount) files, status $($inventory.status))"
} else {
    Write-Json $OutPath $inventory
    Write-Output "Relocation inventory: $($inventory.fileCount) files, $($inventory.v3FileCount) V3 files ($($inventory.v3Lines) V3 gate lines), unlisted reads $($unlisted.Count), status $($inventory.status)"
}
if ($unlisted.Count -ne 0) { $unlisted | ForEach-Object { Write-Warning "$($_.class): $($_.origin) -> $($_.literal) ($($_.resolved))" }; exit 1 }
