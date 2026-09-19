[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$package = Join-Path $root 'docs/guards/V3_ifx'
$fixture = Join-Path $root "artifacts/guards/v3-ifx/authority-fixture-$([Guid]::NewGuid().ToString('N'))"

function Resolve-SyncEntryPoint([string] $PackageRoot) {
    $legacy = Join-Path $PackageRoot 'scripts/Sync-IFXPolicyInputs.ps1'
    $maintenance = Join-Path $PackageRoot 'maintenance/Sync-IFXPolicyInputs.ps1'
    $available = @(@($legacy, $maintenance) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    if ($available.Count -ne 1) { throw "Exactly one policy sync entry point must exist during migration; found $($available.Count)." }
    return [pscustomobject]@{ Path = $available[0]; MaintenancePath = $maintenance }
}

function Assert-SelectionFailure([string] $PackageRoot, [string] $Label) {
    $failed = $false
    try { [void](Resolve-SyncEntryPoint $PackageRoot) } catch { $failed = $_.Exception.Message -match 'Exactly one policy sync entry point' }
    if (-not $failed) { throw "$Label did not fail closed." }
}

New-Item -ItemType Directory -Force -Path $fixture | Out-Null
try {
    $neither = Join-Path $fixture 'path-selection-neither'
    New-Item -ItemType Directory -Force -Path $neither | Out-Null
    Assert-SelectionFailure $neither 'Missing policy sync entry point'

    $both = Join-Path $fixture 'path-selection-both'
    New-Item -ItemType Directory -Force -Path (Join-Path $both 'scripts'), (Join-Path $both 'maintenance') | Out-Null
    Set-Content -LiteralPath (Join-Path $both 'scripts/Sync-IFXPolicyInputs.ps1') -Value '# legacy fixture'
    Set-Content -LiteralPath (Join-Path $both 'maintenance/Sync-IFXPolicyInputs.ps1') -Value '# maintenance fixture'
    Assert-SelectionFailure $both 'Ambiguous policy sync entry points'

    Copy-Item -LiteralPath (Join-Path $package 'policy') -Destination (Join-Path $fixture 'policy') -Recurse
    $selection = Resolve-SyncEntryPoint $package
    $sync = $selection.Path
    $applyArguments = if ($sync -ceq $selection.MaintenancePath) { @('-Mode', 'Apply', '-AcceptMaintenance') } else { @('-Mode', 'Generate') }
    & $sync -Mode Check -TargetRoot $root -PackageRoot $fixture
    $projection = Join-Path $fixture 'policy/g03/catalog.json'
    Add-Content -LiteralPath $projection -Value ' '
    $output = @(& pwsh -NoProfile -File $sync -Mode Check -TargetRoot $root -PackageRoot $fixture 2>&1)
    if ($LASTEXITCODE -eq 0) { throw "Projection drift unexpectedly passed: $($output -join ' | ')" }
    & pwsh -NoProfile -File $sync @applyArguments -TargetRoot $root -PackageRoot $fixture
    if ($LASTEXITCODE -ne 0) { throw "Projection maintenance failed with exit code $LASTEXITCODE." }
    & $sync -Mode Check -TargetRoot $root -PackageRoot $fixture
    Write-Host 'IFX authority projection Check rejects drift and the single declared maintenance entry point restores deterministic content.'
} finally {
    if (Test-Path $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
$global:LASTEXITCODE = 0
