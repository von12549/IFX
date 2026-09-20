[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$package = Join-Path $root 'docs/guards/V3_ifx'
$fixture = Join-Path $root "artifacts/guards/v3-ifx/authority-fixture-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $fixture | Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $package 'policy') -Destination (Join-Path $fixture 'policy') -Recurse
    $sync = Join-Path $package 'scripts/Sync-IFXPolicyInputs.ps1'
    & $sync -Mode Check -TargetRoot $root -PackageRoot $fixture
    $projection = Join-Path $fixture 'policy/g03/catalog.json'
    Add-Content -LiteralPath $projection -Value ' '
    $output = @(& pwsh -NoProfile -File $sync -Mode Check -TargetRoot $root -PackageRoot $fixture 2>&1)
    if ($LASTEXITCODE -eq 0) { throw "Projection drift unexpectedly passed: $($output -join ' | ')" }
    & $sync -Mode Generate -TargetRoot $root -PackageRoot $fixture
    & $sync -Mode Check -TargetRoot $root -PackageRoot $fixture
    $stagePolicy = Join-Path $fixture 'stages/post/policy'
    [void][IO.Directory]::CreateDirectory($stagePolicy)
    foreach ($name in @('baselines', 'g03', 'g04', 'g05', 'layerguard.json')) { Move-Item -LiteralPath (Join-Path $fixture "policy/$name") -Destination $stagePolicy }
    $legacyRegistry = Join-Path $fixture 'policy/authorities.json'
    $registry = Get-Content -LiteralPath $legacyRegistry -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $registry.architecturePolicy.path = $registry.architecturePolicy.path.Replace('/policy/', '/stages/post/policy/')
    foreach ($entry in @($registry.projections) + @($registry.g04Bindings)) { $entry.target = ([string]$entry.target).Replace('policy/', 'stages/post/policy/') }
    $sharedRegistry = Join-Path $fixture 'shared/authorities/authorities.json'
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($sharedRegistry))
    [IO.File]::WriteAllText($sharedRegistry, ($registry | ConvertTo-Json -Depth 100) + "`n", [Text.UTF8Encoding]::new($false))
    Remove-Item -LiteralPath $legacyRegistry -Force
    & $sync -Mode Check -TargetRoot $root -PackageRoot $fixture
    Add-Content -LiteralPath (Join-Path $stagePolicy 'g03/catalog.json') -Value ' '
    $stageOutput = @(& pwsh -NoProfile -File $sync -Mode Check -TargetRoot $root -PackageRoot $fixture 2>&1)
    if ($LASTEXITCODE -eq 0) { throw "Stage-owned projection drift unexpectedly passed: $($stageOutput -join ' | ')" }
    Write-Host 'IFX authority projection supports exactly one legacy or stage-owned layout, rejects drift and restores deterministic content.'
} finally {
    if (Test-Path $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
$global:LASTEXITCODE = 0
