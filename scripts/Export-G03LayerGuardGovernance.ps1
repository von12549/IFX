[CmdletBinding()]
param(
    [string] $OutputPath = 'docs/architecture/review/gates/G03/generated/layerguard-governance-input.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$catalogPath = Join-Path $repositoryRoot 'docs/architecture/review/gates/G03/contract-event-catalog.yaml'
$catalog = Get-Content -Raw -LiteralPath $catalogPath | ConvertFrom-Json -Depth 100
$providerContracts = [ordered]@{}
foreach ($consumer in @($catalog.consumers | Sort-Object module)) {
    $providers = @($catalog.protocols | Where-Object { $consumer.id -in @($_.consumers) } | Select-Object -ExpandProperty provider -Unique | ForEach-Object { ($catalog.modules | Where-Object id -eq $_).name } | Sort-Object -Unique)
    if ($providers.Count -gt 0) { $providerContracts[$consumer.module] = $providers }
}
$handoff = [ordered]@{
    formatVersion = 1
    source = 'docs/architecture/review/gates/G03/contract-event-catalog.yaml'
    catalogSha256 = (Get-FileHash $catalogPath -Algorithm SHA256).Hash.ToLowerInvariant()
    moduleOwnership = @($catalog.modules | Sort-Object id | ForEach-Object { [ordered]@{ module = $_.name; owner = $_.owner; backupOwner = $_.backupOwner } })
    contractRoles = [ordered]@{ provider = 'Contracts'; consumerPort = 'Application'; consumerAdapter = 'IntegrationAdapter' }
    providerContracts = $providerContracts
    adapterEdges = @($catalog.protocols | Sort-Object identity | ForEach-Object { $protocol=$_; foreach($consumerId in @($protocol.consumers)) { $consumer=$catalog.consumers|Where-Object id -eq $consumerId; [ordered]@{ identity=$protocol.identity; kind=$protocol.kind; consumer=$consumer.module; provider=$protocol.provider } } })
    sharedPrimitiveProjects = @($catalog.sharedPrimitives.project | Sort-Object -Unique)
    contractDependencyPolicy = $catalog.contractDependencyPolicy
    waiverPolicy = $catalog.waiverPolicy
    waivers = @($catalog.waivers)
}
$resolvedOutputPath = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $repositoryRoot $OutputPath }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutputPath) | Out-Null
$handoff | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $resolvedOutputPath -Encoding utf8NoBOM
Write-Host "G03 LayerGuard governance input generated: $resolvedOutputPath"
