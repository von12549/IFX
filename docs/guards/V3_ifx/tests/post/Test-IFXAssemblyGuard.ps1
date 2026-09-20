[CmdletBinding()]
param()

# Stage-oriented test group: Post.
$ErrorActionPreference = 'Stop'
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not [IO.File]::Exists((Join-Path $package 'guard-system.json'))) { $package = [IO.Path]::GetFullPath((Join-Path $package '..')) }
if (-not [IO.File]::Exists((Join-Path $package 'guard-system.json'))) { throw 'Cannot resolve the IFX guard package root.' }
$root = [IO.Path]::GetFullPath((Join-Path $package '../../..'))
$legacyQuality = Join-Path $root 'docs/guards/V3_ifx/quality'
$stageQuality = Join-Path $root 'docs/guards/V3_ifx/stages/post/gates/quality'
$qualityFiles = @('Invoke-IFXAssemblyGuard.ps1', 'Invoke-IFXPackageAudit.ps1', 'Invoke-IFXQuality.ps1')
$legacyComplete = @($qualityFiles | Where-Object { -not [IO.File]::Exists((Join-Path $legacyQuality $_)) }).Count -eq 0
$stageComplete = @($qualityFiles | Where-Object { -not [IO.File]::Exists((Join-Path $stageQuality $_)) }).Count -eq 0
if ($legacyComplete -eq $stageComplete) { throw 'Quality must have exactly one complete legacy or stage-owned layout.' }
$qualityRoot = if ($stageComplete) { $stageQuality } else { $legacyQuality }
$guard = Join-Path $qualityRoot 'Invoke-IFXAssemblyGuard.ps1'
$fixture = Join-Path $root "artifacts/guards/v3-ifx/assembly-fixture-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Force -Path $fixture | Out-Null
function Relative([string] $path) { [IO.Path]::GetRelativePath($root, $path).Replace('\','/') }
function Assert-Status([int] $exit, [string] $status, [string[]] $arguments, [string] $reportName) {
    $report = Join-Path $fixture $reportName
    $output = @(& pwsh -NoProfile -File $guard -RepositoryRoot $root -ReportPath (Relative $report) @arguments 2>&1)
    if ($LASTEXITCODE -ne $exit) { throw "Expected exit $exit, got ${LASTEXITCODE}: $($output -join ' | ')" }
    $result = Get-Content -Raw -LiteralPath $report | ConvertFrom-Json -Depth 20
    if ($result.status -ne $status) { throw "Expected $status, got $($result.status)." }
    $result
}
try {
    $allowed = Join-Path $fixture 'AllowedFixture.dll'
    $forbidden = Join-Path $fixture 'ForbiddenFixture.dll'
    $good = Join-Path $fixture 'Good.Domain.dll'
    $bad = Join-Path $fixture 'Bad.Domain.dll'
    Add-Type -TypeDefinition 'public class AllowedFixtureType {}' -OutputAssembly $allowed
    Add-Type -TypeDefinition 'public class ForbiddenFixtureType {}' -OutputAssembly $forbidden
    Add-Type -TypeDefinition 'public class GoodFixture { public AllowedFixtureType Value { get; set; } }' -ReferencedAssemblies $allowed -OutputAssembly $good
    Add-Type -TypeDefinition 'public class BadFixture { public ForbiddenFixtureType Value { get; set; } }' -ReferencedAssemblies $forbidden -OutputAssembly $bad
    $policyPath = Join-Path $fixture 'policy.json'
    @{ allowedReferences = @{ Domain = @([Reflection.AssemblyName]::GetAssemblyName($allowed).Name) } } | ConvertTo-Json -Depth 5 | Set-Content $policyPath

    [void](Assert-Status 0 'pass' @('-PolicyPath',(Relative $policyPath),'-AssemblyPaths',(Relative $good)) 'good.json')
    $badResult = Assert-Status 1 'fail' @('-PolicyPath',(Relative $policyPath),'-AssemblyPaths',(Relative $bad)) 'bad.json'
    if (@($badResult.checks[0].forbiddenReferences).Count -ne 1) { throw 'Forbidden assembly reference was not reported.' }
    [void](Assert-Status 1 'blocked' @('-PolicyPath',(Relative $policyPath),'-AssemblyPaths',(Relative (Join-Path $fixture 'missing.dll'))) 'missing.json')
    $empty = Join-Path $fixture 'empty'; New-Item -ItemType Directory -Path $empty | Out-Null
    [void](Assert-Status 1 'blocked' @('-PolicyPath',(Relative $policyPath),'-DomainProjectRoot',(Relative $empty),'-ExpectedProjectCount','1') 'zero.json')

    $projectRoot = Join-Path $fixture 'stale/IFX.Modules.Fixture.Domain'
    $bin = Join-Path $projectRoot 'bin/Release/net8.0'; New-Item -ItemType Directory -Force -Path $bin | Out-Null
    $project = Join-Path $projectRoot 'IFX.Modules.Fixture.Domain.csproj'; Set-Content $project '<Project Sdk="Microsoft.NET.Sdk" />'
    $source = Join-Path $projectRoot 'Entity.cs'; Set-Content $source 'public class Entity {}'
    $staleDll = Join-Path $bin 'IFX.Modules.Fixture.Domain.dll'; Add-Type -TypeDefinition 'public class StaleFixture {}' -OutputAssembly $staleDll
    (Get-Item $source).LastWriteTimeUtc = [DateTime]::UtcNow.AddMinutes(1)
    $staleResult = Assert-Status 1 'fail' @('-PolicyPath',(Relative $policyPath),'-DomainProjectRoot',(Relative (Join-Path $fixture 'stale')),'-ExpectedProjectCount','1') 'stale.json'
    if (-not $staleResult.checks[0].stale) { throw 'Stale assembly was not reported.' }
    Write-Host 'IFX assembly guard positive, forbidden, missing, zero-match and stale tests passed.'
} finally {
    if (Test-Path $fixture) { Remove-Item -LiteralPath $fixture -Recurse -Force }
}
$global:LASTEXITCODE = 0
