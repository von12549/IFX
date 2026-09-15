[CmdletBinding()]
param([string] $OutputDirectory = 'artifacts/guards/v3-ifx/specialized/plan04')

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
$resolvedOutput = if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $repositoryRoot $OutputDirectory }
New-Item -ItemType Directory -Force -Path $resolvedOutput | Out-Null

$inventoryPath = Join-Path $resolvedOutput 'module-boundary-inventory.json'
$graphPath = Join-Path $resolvedOutput 'module-boundary-dependency-graph.json'
$validators = @(
    [ordered]@{ name = 'boundaryInventory'; script = 'New-Plan04BoundaryInventory.ps1'; arguments = @{ OutputPath = $inventoryPath; GraphPath = $graphPath } },
    [ordered]@{ name = 'extractionPolicy'; script = 'Test-Plan04ExtractionPolicy.ps1'; arguments = @{ StatusPath = (Join-Path $resolvedOutput 'extraction-policy.json') } },
    [ordered]@{ name = 'tenantQueryPolicy'; script = 'Test-Plan04TenantQueryPolicy.ps1'; arguments = @{ InventoryPath = (Join-Path $resolvedOutput 'tenant-query-inventory.json'); StatusPath = (Join-Path $resolvedOutput 'tenant-query-policy.json') } },
    [ordered]@{ name = 'projectionPolicy'; script = 'Test-Plan04ProjectionPolicy.ps1'; arguments = @{ GraphPath = $graphPath; InventoryPath = (Join-Path $resolvedOutput 'cross-module-query-inventory.json'); StatusPath = (Join-Path $resolvedOutput 'projection-policy.json') } },
    [ordered]@{ name = 'abstractionsRetirement'; script = 'Test-AbstractionsRetirement.ps1'; arguments = @{ StatusPath = (Join-Path $resolvedOutput 'abstractions-retirement.json') } }
)

$results = @()
foreach ($validator in $validators) {
    try {
        $arguments = $validator.arguments
        & (Join-Path $PSScriptRoot $validator.script) @arguments
        $results += [ordered]@{ id = $validator.name; passed = $true; error = $null }
    } catch {
        $results += [ordered]@{ id = $validator.name; passed = $false; error = $_.Exception.Message }
    }
}

try {
    $zh = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/architecture/review/module-boundary-evolution.zh-CN.md')
    $en = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/architecture/review/module-boundary-evolution.en.md')
    $diagramRoot = Join-Path $repositoryRoot 'docs/architecture/review/diagrams/plan04'
    $diagramSources = @(Get-ChildItem -LiteralPath $diagramRoot -File -Filter '*.mmd')
    $validDiagrams = @($diagramSources | Where-Object { (Get-Content -Raw -LiteralPath $_.FullName) -match '^(flowchart|stateDiagram)' })
    if ($zh -notmatch 'module-boundary-evolution\.en\.md' -or $en -notmatch 'module-boundary-evolution\.zh-CN\.md' -or $diagramSources.Count -ne 5 -or $validDiagrams.Count -ne 5) {
        throw 'Plan 04 bilingual documentation or diagram sources are incomplete.'
    }
    $results += [ordered]@{ id = 'documentationCurrent'; passed = $true; error = $null }
} catch {
    $results += [ordered]@{ id = 'documentationCurrent'; passed = $false; error = $_.Exception.Message }
}

$summary = [ordered]@{
    formatVersion = 1
    gate = 'Plan04'
    result = if (@($results | Where-Object passed -ne $true).Count -eq 0) { 'passed' } else { 'failed' }
    scope = 'current-policy-validation-historical-frozen-hashes-excluded'
    validators = $results
}
$summaryPath = Join-Path $resolvedOutput 'verification-summary.json'
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding utf8NoBOM
if ($summary.result -ne 'passed') { throw "Plan 04 governance failed: $summaryPath" }
Write-Host "Plan 04 current governance passed: $summaryPath"
