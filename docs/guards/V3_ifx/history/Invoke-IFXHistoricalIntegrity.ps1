[CmdletBinding()]
param(
    [string] $RepositoryRoot,
    [string] $ManifestPath,
    [string] $ReportPath = 'artifacts/guards/v3-ifx/history/summary.json'
)

$ErrorActionPreference = 'Stop'
$root = if ($RepositoryRoot) { [IO.Path]::GetFullPath($RepositoryRoot) } elseif ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..')) }
function Resolve-InRoot([string] $path) {
    $resolved = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $root $path }))
    $prefix = $root.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($resolved -ne $root -and -not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes repository root: $path" }
    $resolved
}
function Hash-CanonicalText([string] $path) {
    $text = [IO.File]::ReadAllText($path).Replace("`r`n", "`n").Replace("`r", "`n")
    ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($text)))).ToLowerInvariant()
}

$checks = @()
try {
    # The manifest is package configuration; the evidence it lists is read from the target repository.
    $manifestFile = if ($ManifestPath) { Resolve-InRoot $ManifestPath } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'manifest.json')) }
    $manifest = Get-Content -Raw -LiteralPath $manifestFile | ConvertFrom-Json -Depth 100
    if ($manifest.formatVersion -ne 1 -or $manifest.status -ne 'historical-integrity-only' -or @($manifest.entries).Count -lt 15 -or @($manifest.references).Count -lt 3) { throw 'History manifest shape or historical label is invalid.' }
    foreach ($entry in $manifest.entries) {
        $full = Resolve-InRoot $entry.path
        $exists = Test-Path -LiteralPath $full -PathType Leaf
        $jsonReadable = $false
        $hashMatches = $false
        $summaryMatches = $false
        if ($exists) {
            try {
                $document = Get-Content -Raw -LiteralPath $full | ConvertFrom-Json -Depth 100
                $jsonReadable = $null -ne $document
                $summaryMatches = $document.formatVersion -eq $entry.formatVersion -and
                    ($(if ($document.PSObject.Properties.Name -contains 'result') { $document.result } else { $null })) -eq $entry.summary.result -and
                    ($(if ($document.PSObject.Properties.Name -contains 'gate') { $document.gate } else { $null })) -eq $entry.summary.gate -and
                    ($(if ($document.PSObject.Properties.Name -contains 'plan') { $document.plan } else { $null })) -eq $entry.summary.plan
            }
            catch { $jsonReadable = $false }
            $hashMatches = (Hash-CanonicalText $full) -eq $entry.sha256
        }
        $checks += [ordered]@{ id = $entry.path; status = if ($exists -and $jsonReadable -and $summaryMatches -and $hashMatches) { 'pass' } else { 'fail' }; exists = $exists; jsonReadable = $jsonReadable; summaryMatches = $summaryMatches; hashMatches = $hashMatches }
    }
    foreach ($reference in $manifest.references) {
        $sourceExists = Test-Path -LiteralPath (Resolve-InRoot $reference.source) -PathType Leaf
        $targetExists = Test-Path -LiteralPath (Resolve-InRoot $reference.target) -PathType Leaf
        $checks += [ordered]@{ id = "$($reference.source) -> $($reference.target)"; status = if ($sourceExists -and $targetExists) { 'pass' } else { 'fail' }; exists = $sourceExists -and $targetExists; jsonReadable = $true; summaryMatches = $true; hashMatches = $true }
    }
    if (@($checks | Where-Object status -eq 'fail').Count -gt 0) { throw 'One or more historical files are missing, invalid, or changed.' }
    $status = 'pass'; $message = 'Frozen evidence is intact; no current readiness conclusion was evaluated.'
} catch {
    $status = 'fail'; $message = $_.Exception.Message
}
$report = [ordered]@{ schemaVersion = 1; mode = 'historical-integrity'; status = $status; checks = $checks; message = $message }
$output = Resolve-InRoot $ReportPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $output) | Out-Null
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $output -Encoding utf8NoBOM
if ($status -ne 'pass') { throw "IFX historical integrity failed: $output" }
Write-Host "IFX historical integrity passed: $output"
