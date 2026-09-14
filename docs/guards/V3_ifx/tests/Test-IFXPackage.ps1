[CmdletBinding()]
param([string] $NuGetConfig)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repository = [IO.Path]::GetFullPath((Join-Path $package '../../..'))
$artifacts = [IO.Path]::GetFullPath((Join-Path $repository 'artifacts/guards'))
$fixture = [IO.Path]::GetFullPath((Join-Path $artifacts "v3-ifx-package-test-$([Guid]::NewGuid().ToString('N'))"))
if (-not $fixture.StartsWith($artifacts.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test fixture path.' }
[void] [IO.Directory]::CreateDirectory($fixture)

function Copy-ToFixture {
    param([string] $Source, [string] $Relative)
    $destination = [IO.Path]::GetFullPath((Join-Path $fixture $Relative))
    if (-not $destination.StartsWith($fixture + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe fixture file: $Relative" }
    [void] [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
    [IO.File]::WriteAllBytes($destination, [IO.File]::ReadAllBytes($Source))
}

Push-Location $repository
try {
    $sourcePaths = @(git ls-files -- src)
    if ($LASTEXITCODE -ne 0 -or $sourcePaths.Count -eq 0) { throw 'Cannot enumerate tracked IFX source files.' }
    foreach ($relative in $sourcePaths) {
        if ($relative -eq 'src/layerguard.json') { continue }
        Copy-ToFixture (Join-Path $repository $relative) $relative
    }
    foreach ($file in Get-ChildItem -LiteralPath $package -File -Recurse) {
        $relative = [IO.Path]::GetRelativePath($package, $file.FullName).Replace('\', '/')
        if ($relative -match '(^|/)(bin|obj)/') { continue }
        Copy-ToFixture $file.FullName "docs/guards/V3_ifx/$relative"
    }
}
finally { Pop-Location }

$runner = Join-Path $fixture 'docs/guards/V3_ifx/scripts/Invoke-IFX.ps1'
$arguments = @('-NoProfile', '-File', $runner)
if ($NuGetConfig) {
    $config = if ([IO.Path]::IsPathRooted($NuGetConfig)) { $NuGetConfig } else { Join-Path $repository $NuGetConfig }
    if (-not [IO.File]::Exists($config)) { throw "NuGet config is missing: $config" }
    Copy-ToFixture $config 'NuGet.Test.Config'
    $arguments += @('-NuGetConfig', 'NuGet.Test.Config')
}

$positive = @(& pwsh @arguments -Mode Test -TargetRoot $fixture 2>&1)
if ($LASTEXITCODE -ne 0) { throw "Isolated package test failed: $($positive -join ' | ')" }

$project = Join-Path $fixture 'src/Modules/CRM/IFX.Modules.CRM.Domain/IFX.Modules.CRM.Domain.csproj'
$text = [IO.File]::ReadAllText($project)
if (-not $text.Contains('</Project>')) { throw 'CRM fixture project has no closing Project element.' }
$reference = '<ItemGroup><ProjectReference Include="../IFX.Modules.CRM.Contracts/IFX.Modules.CRM.Contracts.csproj" /></ItemGroup>'
[IO.File]::WriteAllText($project, $text.Replace('</Project>', "$reference</Project>"))
$negative = @(& pwsh @arguments -Mode Scan -TargetRoot $fixture 2>&1)
if ($LASTEXITCODE -eq 0) { throw 'IFX LayerGuard accepted the deliberately forbidden Domain-to-Contracts edge.' }
$reportPath = Join-Path $fixture 'artifacts/guards/v3-ifx-layerguard.json'
if (-not [IO.File]::Exists($reportPath)) { throw 'Negative scan produced no report.' }
$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
if (@($report.violations | Where-Object { $_.ref -eq 'L2.2' }).Count -eq 0) {
    throw 'Negative scan failed without an L2.2 finding.'
}

$manifest = Join-Path $fixture 'docs/guards/V3_ifx/policy/g04/runtime-manifest.json'
$data = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json -AsHashtable
$data.bindings.moduleManifest.path = 'deployment/g04/module-manifest.json'
[IO.File]::WriteAllText($manifest, ($data | ConvertTo-Json -Depth 100), [Text.UTF8Encoding]::new($false))
$invalidBinding = @(& pwsh @arguments -Mode Validate -TargetRoot $fixture 2>&1)
if ($LASTEXITCODE -eq 0) { throw 'IFX package accepted a binding outside its local policy tree.' }

Write-Host "IFX isolated positive, L2.2 negative, and external-binding negative tests passed. Evidence: $fixture"
