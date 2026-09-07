[CmdletBinding()]
param(
    [ValidateRange(0, 9)]
    [int] $Phase = 0,
    [string] $ReportPath
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$inventoryPath = Join-Path $repositoryRoot 'docs/architecture/review/evidence/gates/G03/G03-contract-event-inventory.json'
if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = "docs/architecture/review/evidence/gates/G03/G03-phase$Phase-guard-report.json"
}
$resolvedReportPath = if ([System.IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $repositoryRoot $ReportPath }
$generator = Join-Path $PSScriptRoot 'Invoke-G03ContractEventInventory.ps1'

& $generator -ReportPath $inventoryPath
$firstHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryPath).Hash.ToLowerInvariant()
& $generator -ReportPath $inventoryPath
$secondHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryPath).Hash.ToLowerInvariant()
$inventory = Get-Content -Raw -LiteralPath $inventoryPath | ConvertFrom-Json -Depth 100

$checks = [ordered]@{
    deterministicInventory = $firstHash -eq $secondHash
    exactAbstractionProjectCount = $inventory.counts.abstractionProjects -eq 4
    exactReaderCount = $inventory.counts.readers -eq 4
    exactReaderMethodCount = $inventory.counts.readerMethods -eq 15
    exactDtoCount = $inventory.counts.dtos -eq 7
    exactIntegrationEventCount = $inventory.counts.integrationEvents -eq 20
    messagingSurfaceInventoried = $inventory.counts.messagingAbstractionTypes -eq 4
    generatedDirectoriesExcluded = @($inventory.publicSurface.declaration.file | Where-Object { $_ -match '(^|/)(bin|obj)/' }).Count -eq 0
}

$report = [ordered]@{
    formatVersion = 1
    gate = 'G03'
    phase = $Phase
    result = if ($checks.Values -contains $false) { 'failed' } else { 'passed' }
    checks = $checks
    counts = $inventory.counts
    sha256 = [ordered]@{ inventory = $secondHash }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedReportPath -Encoding utf8NoBOM
if ($report.result -ne 'passed') { throw "G03 Phase $Phase guard failed. Report: $resolvedReportPath" }
Write-Host "G03 Phase $Phase guard passed. Report: $resolvedReportPath"
