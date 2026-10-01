# IFX I2-B amendment A3 (Plan 20260929-v4-ifx-i2b-ci-evidence-and-bundle) step A3-2: copy the relocate origins of the
# closure inventory byte for byte into docs/guards/v4-adoption (rulings R12, R13) and append them to
# producers/origins.json, each with its own step and origin commit, after the A2 entries. The extract origin (the
# aggregate, ruling R14) is not copied; A3-3 writes it. -Check is the drift control for the A3 origins: it re-hashes each
# origin and reports any change since the copy (the lab originals stay in place). The A2 control
# (Copy-IFX051Producers.ps1 -Check) keeps covering every entry, including these.
[CmdletBinding()]
param(
    [string]$InventoryPath = (Join-Path $PSScriptRoot 'closure-inventory.json'),
    [switch]$Check
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function LfHash([string]$Path) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($Path).ReplaceLineEndings("`n")))).ToLowerInvariant() }
$inventory = Get-Content -LiteralPath $InventoryPath -Raw | ConvertFrom-Json -Depth 30
if ($inventory.status -cne 'pass') { throw 'The closure inventory is not passing.' }
$originsPath = Join-Path $repo 'docs/guards/v4-adoption/producers/origins.json'
$origins = Get-Content -LiteralPath $originsPath -Raw | ConvertFrom-Json -Depth 20
$a3 = @($origins.files | Where-Object { $_.PSObject.Properties['step'] -and $_.step -ceq 'A3-2' })

if ($Check) {
    if ($a3.Count -eq 0) { throw 'origins.json has no A3-2 entries.' }
    $drift = [Collections.Generic.List[object]]::new()
    foreach ($f in $a3) {
        $path = Join-Path $repo $f.origin
        if (-not [IO.File]::Exists($path)) { $drift.Add([ordered]@{ origin = $f.origin; change = 'removed' }); continue }
        if ((LfHash $path) -cne $f.lfSha256) { $drift.Add([ordered]@{ origin = $f.origin; change = 'content'; recordedLfSha256 = $f.lfSha256; currentLfSha256 = LfHash $path }) }
    }
    $result = [ordered]@{ formatVersion = 1; kind = 'ifx-052-closure-origin-drift'; fileCount = $a3.Count; drift = @($drift); status = $(if ($drift.Count -eq 0) { 'no-drift' } else { 'drift-for-review' }) }
    $result | ConvertTo-Json -Depth 10
    if ($drift.Count -ne 0) { exit 3 }
    exit 0
}

if ($a3.Count -ne 0) { throw 'origins.json already has A3-2 entries: the byte copy is done once.' }
$head = (& git -C $repo rev-parse HEAD).Trim()
$moves = @($inventory.origins | Where-Object { $_.kind -cne 'lab-aggregate' })
$rows = foreach ($f in $moves) {
    $source = Join-Path $repo $f.origin; $destination = Join-Path $repo $f.destination
    if ([IO.File]::Exists($destination)) { throw "Destination already exists: $($f.destination)" }
    if ((Hash $source) -cne $f.sha256) { throw "Origin changed since the inventory: $($f.origin)" }
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
    [IO.File]::Copy($source, $destination)
    if ((Hash $destination) -cne $f.sha256) { throw "Copy is not byte-identical: $($f.destination)" }
    [ordered]@{ origin = $f.origin; destination = $f.destination; kind = $f.kind; gates = @(@($inventory.origins | Where-Object origin -CEQ $f.origin)[0].usedBy); sha256 = $f.sha256; lfSha256 = $f.lfSha256; gitBlob = $f.gitBlob; step = 'A3-2'; originCommit = $head }
}
$text = [IO.File]::ReadAllText($originsPath)
$document = $text | ConvertFrom-Json -Depth 20 -AsHashtable
$document['files'] = @(@($document['files']) + @($rows))
$document['amendments'] = @([ordered]@{ step = 'A3-2'; originCommit = $head; closureInventorySha256 = LfHash $InventoryPath; rule = 'A3 entries come from the lab tree (candidates) at their own originCommit; Copy-IFX052Closure.ps1 -Check reports any later origin change as drift for review (ruling R13).' })
[IO.File]::WriteAllText($originsPath, (($document | ConvertTo-Json -Depth 10).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
Write-Output "Copied $(@($rows).Count) files byte for byte into docs/guards/v4-adoption; origins.json extended."
