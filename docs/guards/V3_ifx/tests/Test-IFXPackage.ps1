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
        Copy-ToFixture (Join-Path $repository $relative) $relative
    }
    Copy-ToFixture (Join-Path $repository 'docs/Directory.Packages.props') 'docs/Directory.Packages.props'
    # The guard build baseline is canonical in V3 (Plan 06 D14); the package resolves it from ../V3/build.
    $v3Build = Join-Path $repository 'docs/guards/V3/build'
    foreach ($file in Get-ChildItem -LiteralPath $v3Build -File -Recurse) {
        $relative = [IO.Path]::GetRelativePath($v3Build, $file.FullName).Replace('\', '/')
        if ($relative -match '(^|/)(bin|obj)/') { continue }
        Copy-ToFixture $file.FullName "docs/guards/V3/build/$relative"
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
$arguments += '-SkipAuthorityCheck'
if ($NuGetConfig) {
    $config = if ([IO.Path]::IsPathRooted($NuGetConfig)) { $NuGetConfig } else { Join-Path $repository $NuGetConfig }
    if (-not [IO.File]::Exists($config)) { throw "NuGet config is missing: $config" }
    Copy-ToFixture $config 'NuGet.Test.Config'
    $arguments += @('-NuGetConfig', 'NuGet.Test.Config')
}

$positive = @(& pwsh @arguments -Mode Test -TargetRoot $fixture 2>&1)
if ($LASTEXITCODE -ne 0) { throw "Isolated package test failed: $($positive -join ' | ')" }
$sourceTreeOutput = @(Get-ChildItem -LiteralPath (Join-Path $fixture 'docs/guards') -Recurse -Directory -Force | Where-Object { $_.Name -in @('bin', 'obj') })
if ($sourceTreeOutput.Count -gt 0) { throw "Guard build wrote output into the package source tree: $(($sourceTreeOutput | ForEach-Object FullName) -join ', ')" }
foreach ($phase in @('LayerGuard.imports.pre-build.json', 'LayerGuard.Ifx.imports.pre-build.json', 'LayerGuard.Tests.imports.pre-build.json', 'LayerGuard.Ifx.Tests.imports.pre-build.json', 'LayerGuard.Tests.imports.post-build.json')) {
    $importReport = Join-Path $fixture "artifacts/guards/v3-ifx/build/architecture-conformance/$phase"
    if (-not [IO.File]::Exists($importReport) -or (Get-Content -LiteralPath $importReport -Raw | ConvertFrom-Json).status -ne 'pass') { throw "Guard import allowlist evidence is missing or failing: $phase" }
}

# Plan 06 P6.1 (D26): Generate is read-only, and Check verifies the single LayerGuard source tree.
$templateRoot = Join-Path $fixture 'docs/guards/V3_ifx/templates/ifx-layerguard'
$retiredCopy = Join-Path $fixture 'docs/guards/V3_ifx/generated/dotnet/LayerGuard'
$generate = @(& pwsh @arguments -Mode Generate -TargetRoot $fixture 2>&1)
if ($LASTEXITCODE -ne 0 -or [IO.Directory]::Exists($retiredCopy)) { throw "IFX Generate is not read-only or failed: $($generate -join ' | ')" }
function Assert-CheckFails([string] $Label, [scriptblock] $Mutate, [string] $Cleanup, [string] $ExpectText) {
    & $Mutate
    try {
        $output = @(& pwsh @arguments -Mode Check -TargetRoot $fixture 2>&1)
        if ($LASTEXITCODE -eq 0 -or -not (($output -join ' ') -replace '\s+', ' ').Contains($ExpectText, [StringComparison]::Ordinal)) { throw "IFX Check accepted ${Label}: $($output -join ' | ')" }
    }
    finally { if (Test-Path -LiteralPath $Cleanup) { Remove-Item -LiteralPath $Cleanup -Recurse -Force } }
}
function Write-FixtureFile([string] $Path, [string] $Text) { [void] [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)); [IO.File]::WriteAllText($Path, $Text) }
Assert-CheckFails 'a recreated generated copy' { Write-FixtureFile (Join-Path $retiredCopy 'LayerGuard.slnx') '<Solution />' } (Join-Path $fixture 'docs/guards/V3_ifx/generated/dotnet') 'The retired generated LayerGuard copy exists again'
Assert-CheckFails 'an undeclared project' { Write-FixtureFile (Join-Path $templateRoot 'tests/Extra.Tests/Extra.Tests.csproj') '<Project />' } (Join-Path $templateRoot 'tests/Extra.Tests') 'LayerGuard.slnx projects differ from the source tree'
Assert-CheckFails 'an orphaned fixture' { Write-FixtureFile (Join-Path $templateRoot 'tests/fixtures/Orphan/Orphan.Domain/Orphan.Domain.csproj') '<Project />' } (Join-Path $templateRoot 'tests/fixtures/Orphan') 'LayerGuard fixtures differ from the fixtures the tests name'
Assert-CheckFails 'a source file outside the trusted component manifest' { Write-FixtureFile (Join-Path $templateRoot 'NOTES.md') 'untracked' } (Join-Path $templateRoot 'NOTES.md') 'LayerGuard source file is outside the trusted component manifest'
# Plan 06 P6.3 (D27): the solution holds exactly the engine, the IFX facade and their test projects, with explicit references.
function Assert-CheckFailsWithEdit([string] $Label, [string] $Path, [scriptblock] $Edit, [string] $ExpectText) {
    $original = [IO.File]::ReadAllBytes($Path)
    try {
        & $Edit
        $output = @(& pwsh @arguments -Mode Check -TargetRoot $fixture 2>&1)
        if ($LASTEXITCODE -eq 0 -or -not (($output -join ' ') -replace '\s+', ' ').Contains($ExpectText, [StringComparison]::Ordinal)) { throw "IFX Check accepted ${Label}: $($output -join ' | ')" }
    }
    finally { [IO.File]::WriteAllBytes($Path, $original) }
}
$solutionFile = Join-Path $templateRoot 'LayerGuard.slnx'
$ifxFacade = Join-Path $templateRoot 'src/LayerGuard.Ifx/LayerGuard.Ifx.csproj'
$ifxTests = Join-Path $templateRoot 'tests/LayerGuard.Ifx.Tests/LayerGuard.Ifx.Tests.csproj'
Assert-CheckFailsWithEdit 'a missing IFX facade project' $ifxFacade { Remove-Item -LiteralPath $ifxFacade -Force } 'LayerGuard.slnx projects differ from the source tree'
Assert-CheckFailsWithEdit 'an unexpected declared project' $solutionFile {
    Write-FixtureFile (Join-Path $templateRoot 'src/Extra/Extra.csproj') '<Project />'
    [IO.File]::WriteAllText($solutionFile, [IO.File]::ReadAllText($solutionFile).Replace('</Solution>', '<Project Path="src/Extra/Extra.csproj" /></Solution>'))
} 'LayerGuard.slnx projects differ from the expected project set'
Remove-Item -LiteralPath (Join-Path $templateRoot 'src/Extra') -Recurse -Force
Assert-CheckFailsWithEdit 'IFX tests that bypass the IFX facade' $ifxTests { [IO.File]::WriteAllText($ifxTests, [IO.File]::ReadAllText($ifxTests).Replace('src\LayerGuard.Ifx\LayerGuard.Ifx.csproj', 'src\LayerGuard\LayerGuard.csproj')) } 'project references differ from the expected set'
Assert-CheckFailsWithEdit 'a wildcard project reference' $ifxTests { [IO.File]::WriteAllText($ifxTests, [IO.File]::ReadAllText($ifxTests).Replace('src\LayerGuard.Ifx\LayerGuard.Ifx.csproj', 'src\*\*.csproj')) } 'uses a wildcard project reference'

$qualityRunner = [IO.File]::ReadAllText((Join-Path $package 'quality/Invoke-IFXQuality.ps1'))
$requiredQualityGates = @(
    '-warnaserror:NU1603',
    'Invoke-IFXPackageAudit.ps1',
    "@('--json', '--audit-level=high')",
    'npm run lint -- --max-warnings=0'
)
foreach ($gate in $requiredQualityGates) {
    if (-not $qualityRunner.Contains($gate, [StringComparison]::Ordinal)) {
        throw "IFX quality runner is missing the blocking gate: $gate"
    }
}

$buildPolicy = [IO.File]::ReadAllText((Join-Path $repository 'Directory.Build.props'))
foreach ($requiredPolicy in @('<NuGetAuditMode>all</NuGetAuditMode>', 'NU1903;NU1904')) {
    if (-not $buildPolicy.Contains($requiredPolicy, [StringComparison]::Ordinal)) {
        throw "Repository build policy is missing the transitive audit gate: $requiredPolicy"
    }
}
$centralPackages = [IO.File]::ReadAllText((Join-Path $repository 'Directory.Packages.props'))
foreach ($requiredPackagePolicy in @(
    '<ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>',
    '<PackageVersion Include="Microsoft.EntityFrameworkCore" Version="8.0.31" />',
    '<PackageVersion Include="Microsoft.EntityFrameworkCore.SqlServer" Version="8.0.31" />')) {
    if (-not $centralPackages.Contains($requiredPackagePolicy, [StringComparison]::Ordinal)) {
        throw "Repository central package policy is missing: $requiredPackagePolicy"
    }
}

$policyFile = Join-Path $fixture 'docs/guards/V3_ifx/policy/layerguard.json'
$policyBytes = [IO.File]::ReadAllBytes($policyFile)
try {
    $policyData = [Text.Encoding]::UTF8.GetString($policyBytes) | ConvertFrom-Json -AsHashtable -Depth 100
    $policyData.ruleRefs[1].ref = 'L2.3X'
    [IO.File]::WriteAllText($policyFile, (ConvertTo-Json -InputObject $policyData -Depth 100), [Text.UTF8Encoding]::new($false))
    $idDrift = @(& pwsh @arguments -Mode Validate -TargetRoot $fixture 2>&1)
    if ($LASTEXITCODE -eq 0 -or ($idDrift -join ' | ') -notmatch 'rule ID drift') { throw 'IFX package accepted stage/policy rule ID drift.' }
}
finally { [IO.File]::WriteAllBytes($policyFile, $policyBytes) }

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

Write-Host "IFX isolated positive, read-only Generate, source and project-set Check negatives, rule-ID drift negative, L2.2 negative, and external-binding negative tests passed. Evidence: $fixture"
$global:LASTEXITCODE = 0
