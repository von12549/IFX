[CmdletBinding()]
param(
    [string] $ApiSnapshotPath = 'docs/architecture/review/gates/G03/snapshots/G03-sync-api-snapshot.json',
    [string] $SerializationSnapshotPath = 'docs/architecture/review/gates/G03/snapshots/G03-serialization-golden.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$catalog = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/architecture/review/gates/G03/contract-event-catalog.yaml') | ConvertFrom-Json -Depth 100
$temporaryInventory = Join-Path ([IO.Path]::GetTempPath()) "g03-snapshot-$([Guid]::NewGuid().ToString('N')).json"
try {
    & (Join-Path $PSScriptRoot 'Invoke-G03ContractEventInventory.ps1') -ReportPath $temporaryInventory -BaselineCommit HEAD
    $inventory = Get-Content -Raw -LiteralPath $temporaryInventory | ConvertFrom-Json -Depth 100
} finally { Remove-Item -LiteralPath $temporaryInventory -Force -ErrorAction SilentlyContinue }

$api = [ordered]@{
    formatVersion = 1; status = 'authoritative-current'
    protocols = @($catalog.protocols | Where-Object kind -eq 'sync' | Sort-Object identity | ForEach-Object {
        $protocol = $_
        $surface = $inventory.publicSurface | Where-Object { $_.project -eq $protocol.source.project -and $_.name -eq $protocol.source.type } | Select-Object -First 1
        $method = $surface.methods | Where-Object name -eq $protocol.source.member | Select-Object -First 1
        $moduleName = ($catalog.modules | Where-Object id -eq $protocol.provider | Select-Object -First 1).name
        [ordered]@{ identity = $protocol.identity; version = $protocol.version; lifecycle = $protocol.lifecycle; sourceSignature = $method.signature; targetNamespace = "$($protocol.source.project).V$($protocol.version)"; fields = @($protocol.fields | Select-Object name, required, classification) }
    })
}
$serialization = [ordered]@{
    formatVersion = 1; status = 'authoritative-current'; unknownFields = 'ignored-by-consumers'; propertyNaming = 'camelCase'
    schemas = @($catalog.protocols | Sort-Object identity | ForEach-Object {
        [ordered]@{ identity = $_.identity; version = $_.version; kind = $_.kind; lifecycle = $_.lifecycle; fields = @($_.fields | Select-Object name, required, classification); compatibility = if ($_.kind -eq 'event') { 'immutable envelope plus provider-owned payload' } else { 'capability request/response' } }
    })
}
foreach ($item in @(@{path=$ApiSnapshotPath; value=$api}, @{path=$SerializationSnapshotPath; value=$serialization})) {
    $path = if ([IO.Path]::IsPathRooted($item.path)) { $item.path } else { Join-Path $repositoryRoot $item.path }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
    $item.value | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $path -Encoding utf8NoBOM
}
Write-Host 'G03 compatibility snapshots generated.'
