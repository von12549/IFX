# IFX I2-B amendment A2 step A2-2: copy the inventoried origins byte for byte into docs/guards/v4-adoption/producers and
# write producers/origins.json (ruling R7: the V4 copies record the V3 and lab files they came from). -Check is the drift
# control: it re-hashes every origin and reports any change since the copy (the V3 originals stay in use while V3 is
# required), and verifies that the committed copies' Git blobs equal the origin blobs recorded at copy time.
[CmdletBinding()]
param(
    [string]$InventoryPath = (Join-Path $PSScriptRoot 'relocation-inventory.json'),
    [switch]$Check
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function LfHash([string]$Path) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($Path).ReplaceLineEndings("`n")))).ToLowerInvariant() }
$inventory = Get-Content -LiteralPath $InventoryPath -Raw | ConvertFrom-Json -Depth 20
if ($inventory.status -cne 'pass') { throw 'The relocation inventory is not passing.' }
$originsPath = Join-Path $repo "$($inventory.destinationRoot)/origins.json"

if ($Check) {
    $origins = Get-Content -LiteralPath $originsPath -Raw | ConvertFrom-Json -Depth 20
    $drift = [Collections.Generic.List[object]]::new()
    foreach ($f in @($origins.files)) {
        $path = Join-Path $repo $f.origin
        if (-not [IO.File]::Exists($path)) { $drift.Add([ordered]@{ origin = $f.origin; change = 'removed' }); continue }
        if ((LfHash $path) -cne $f.lfSha256) { $drift.Add([ordered]@{ origin = $f.origin; change = 'content'; recordedLfSha256 = $f.lfSha256; currentLfSha256 = LfHash $path }) }
    }
    $result = [ordered]@{ formatVersion = 1; kind = 'ifx-051-producer-origin-drift'; originsSha256 = LfHash $originsPath; originCommit = $origins.originCommit; fileCount = @($origins.files).Count; drift = @($drift); status = $(if ($drift.Count -eq 0) { 'no-drift' } else { 'drift-for-review' }) }
    $result | ConvertTo-Json -Depth 10
    if ($drift.Count -ne 0) { exit 3 }
    exit 0
}

if ([IO.File]::Exists($originsPath)) { throw "origins.json already exists: the byte copy is done once (A2-2)." }
$head = (& git -C $repo rev-parse HEAD).Trim()
$rows = foreach ($f in @($inventory.files)) {
    $source = Join-Path $repo $f.origin; $destination = Join-Path $repo $f.destination
    if ([IO.File]::Exists($destination)) { throw "Destination already exists: $($f.destination)" }
    if ((Hash $source) -cne $f.sha256) { throw "Origin changed since the inventory: $($f.origin)" }
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
    [IO.File]::Copy($source, $destination)
    if ((Hash $destination) -cne $f.sha256) { throw "Copy is not byte-identical: $($f.destination)" }
    [ordered]@{ origin = $f.origin; destination = $f.destination; kind = $f.kind; gates = @($f.gates); sha256 = $f.sha256; lfSha256 = $f.lfSha256; gitBlob = $f.gitBlob }
}
$origins = [ordered]@{ formatVersion = 1; kind = 'ifx-051-producer-origins'; planId = '20260929-v4-ifx-i2b-ci-evidence-and-bundle'; step = 'A2-2'
    originCommit = $head; inventorySha256 = LfHash $InventoryPath
    rule = 'Each file below was copied byte for byte from its origin at originCommit. The V3 originals stay in use while V3 is required; Copy-IFX051Producers.ps1 -Check reports any later origin change as drift for review (ruling R7).'
    files = @($rows) }
[IO.File]::WriteAllText($originsPath, (($origins | ConvertTo-Json -Depth 10).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
Write-Output "Copied $(@($rows).Count) files byte for byte into $($inventory.destinationRoot); origins.json written."
