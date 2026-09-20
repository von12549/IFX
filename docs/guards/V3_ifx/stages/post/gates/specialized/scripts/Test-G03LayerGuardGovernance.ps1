[CmdletBinding()]
param(
    [string] $ReportPath = 'docs/architecture/review/evidence/gates/G03/G03-layerguard-handoff-report.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = if ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../../../../..')) }
$resolvedReportPath = if ([IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $repositoryRoot $ReportPath }
$outputPath = Join-Path (Split-Path -Parent $resolvedReportPath) 'layerguard-governance-input.generated.json'
& (Join-Path $PSScriptRoot 'Export-G03LayerGuardGovernance.ps1') -OutputPath $outputPath
$firstHash = (Get-FileHash $outputPath -Algorithm SHA256).Hash.ToLowerInvariant()
& (Join-Path $PSScriptRoot 'Export-G03LayerGuardGovernance.ps1') -OutputPath $outputPath
$secondHash = (Get-FileHash $outputPath -Algorithm SHA256).Hash.ToLowerInvariant()
$input = Get-Content -Raw -LiteralPath $outputPath | ConvertFrom-Json -Depth 100
$catalog = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/architecture/review/gates/G03/contract-event-catalog.yaml') | ConvertFrom-Json -Depth 100
$expectedEdges = @(@($catalog.protocols) + @($catalog.infrastructureProtocols | Where-Object { $null -ne $_ }) | ForEach-Object { $_.consumers }).Count
$checks = [ordered]@{
    deterministic = $firstHash -eq $secondHash
    sourceIsCatalog = $input.source -eq 'docs/architecture/review/gates/G03/contract-event-catalog.yaml'
    moduleOwnersPresent = @($input.moduleOwnership | Where-Object { [string]::IsNullOrWhiteSpace($_.owner) -or [string]::IsNullOrWhiteSpace($_.backupOwner) -or $_.owner -eq $_.backupOwner }).Count -eq 0
    providerGraphPresent = @($input.adapterEdges).Count -eq $expectedEdges -and $expectedEdges -ge 4
    sharedAllowlistPresent = @($input.sharedPrimitiveProjects).Count -eq 2 -and
        'IFX.Platform.Context.Contracts' -in $input.sharedPrimitiveProjects -and
        'IFX.Platform.Messaging.Contracts' -in $input.sharedPrimitiveProjects
    waiverPolicyPresent = @($input.waiverPolicy.unwaivable).Count -eq 6 -and $input.waiverPolicy.maximumDays -eq 90
}
$report = [ordered]@{ formatVersion=1; gate='G03'; result=if($checks.Values -contains $false){'failed'}else{'passed'}; checks=$checks; sha256=$secondHash; counts=[ordered]@{modules=@($input.moduleOwnership).Count; edges=@($input.adapterEdges).Count; sharedProjects=@($input.sharedPrimitiveProjects).Count; waivers=@($input.waivers).Count} }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedReportPath -Encoding utf8NoBOM
if ($report.result -ne 'passed') { throw "G03 LayerGuard handoff validation failed: $resolvedReportPath" }
Write-Host "G03 LayerGuard governance handoff passed: $resolvedReportPath"
