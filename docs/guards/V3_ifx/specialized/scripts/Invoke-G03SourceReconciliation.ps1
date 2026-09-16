[CmdletBinding()]
param(
    [string] $ReportPath = 'docs/architecture/review/evidence/gates/G03/G03-source-reconciliation.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = if ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..')) }
$catalogPath = Join-Path $repositoryRoot 'docs/architecture/review/gates/G03/contract-event-catalog.yaml'
$temporaryInventory = Join-Path ([IO.Path]::GetTempPath()) "g03-inventory-$([Guid]::NewGuid().ToString('N')).json"
try {
    & (Join-Path $PSScriptRoot 'Invoke-G03ContractEventInventory.ps1') -ReportPath $temporaryInventory -BaselineCommit HEAD
    $inventory = Get-Content -Raw -LiteralPath $temporaryInventory | ConvertFrom-Json -Depth 100
    $catalog = Get-Content -Raw -LiteralPath $catalogPath | ConvertFrom-Json -Depth 100

    $sourceKeys = @()
    foreach ($surface in @($inventory.publicSurface | Where-Object project -like '*.Abstractions')) {
        $sourceKeys += "$($surface.project)|$($surface.name)|"
        foreach ($method in @($surface.methods)) { $sourceKeys += "$($surface.project)|$($surface.name)|$($method.name)" }
    }
    $catalogKeys = @($catalog.publicSurface | Where-Object lifecycle -eq 'LegacyPendingMigration' | ForEach-Object { "$($_.project)|$($_.type)|$($_.member)" })
    $unregistered = @($sourceKeys | Where-Object { $_ -notin $catalogKeys } | Sort-Object -Unique)
    $missingSource = @($catalogKeys | Where-Object { $_ -notin $sourceKeys } | Sort-Object -Unique)
    $protocolEvidence = @()
    foreach ($protocol in @($catalog.protocols)) {
        $surface = $inventory.publicSurface | Where-Object { $_.project -eq $protocol.source.project -and $_.name -eq $protocol.source.type } | Select-Object -First 1
        $sourceExists = $null -ne $surface
        $memberExists = [string]::IsNullOrWhiteSpace($protocol.source.member) -or $protocol.source.member -in @($surface.methods.name)
        $consumerEvidence = if ($protocol.kind -eq 'event') {
            @($surface.sourceSites | Where-Object kind -eq 'handler').Count -gt 0
        } else {
            $adapterStem = $protocol.source.type -replace '^I', '' -replace 'Contract$', ''
            $missingConsumers = @($protocol.consumers | Where-Object {
                $consumer = $catalog.consumers | Where-Object id -eq $_ | Select-Object -First 1
                $consumerModule = $consumer.module
                $consumerName = ($catalog.modules | Where-Object id -eq $consumerModule | Select-Object -First 1).name
                $consumerRoot = Join-Path $repositoryRoot "src/Modules/$consumerName"
                if (-not (Test-Path -LiteralPath $consumerRoot)) {
                    $true
                } else {
                    $sourceFiles = @(Get-ChildItem $consumerRoot -Recurse -File -Filter '*.cs' | Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' })
                    $directContractReference = @($sourceFiles | Select-String -SimpleMatch $protocol.source.type).Count -gt 0
                    $clientBackedAdapter = @($sourceFiles | Where-Object { $_.BaseName -like "$adapterStem*Adapter" } | Select-String -Pattern '\bClient\b').Count -gt 0
                    -not ($directContractReference -or $clientBackedAdapter)
                }
            })
            $missingConsumers.Count -eq 0
        }
        $protocolEvidence += [ordered]@{ identity = $protocol.identity; sourceExists = $sourceExists; memberExists = $memberExists; currentConsumerSiteExists = $consumerEvidence }
    }
    $failedProtocolEvidence = @($protocolEvidence | Where-Object { -not $_.sourceExists -or -not $_.memberExists -or -not $_.currentConsumerSiteExists })
    $report = [ordered]@{
        formatVersion = 1; gate = 'G03'; result = if ($unregistered.Count -eq 0 -and $missingSource.Count -eq 0 -and $failedProtocolEvidence.Count -eq 0) { 'passed' } else { 'failed' }
        mode = $catalog.mode
        counts = [ordered]@{ sourceSurface = $sourceKeys.Count; catalogSurface = $catalogKeys.Count; protocols = @($catalog.protocols).Count; unregistered = $unregistered.Count; missingSource = $missingSource.Count; failedProtocolEvidence = $failedProtocolEvidence.Count }
        protocols = $protocolEvidence
        failures = [ordered]@{ unregistered = $unregistered; missingSource = $missingSource; protocolEvidence = $failedProtocolEvidence }
    }
    $resolvedReportPath = if ([IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $repositoryRoot $ReportPath }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
    $report | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $resolvedReportPath -Encoding utf8NoBOM
    if ($report.result -ne 'passed') { throw "G03 source reconciliation failed. Report: $resolvedReportPath" }
    Write-Host "G03 source reconciliation passed: $resolvedReportPath"
} finally {
    Remove-Item -LiteralPath $temporaryInventory -Force -ErrorAction SilentlyContinue
}
