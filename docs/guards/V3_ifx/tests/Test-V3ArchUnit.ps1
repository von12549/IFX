[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repo = [IO.Path]::GetFullPath((Join-Path $package '../../..'))
$parent = [IO.Path]::GetFullPath((Join-Path $repo 'artifacts/guards'))
$fixture = [IO.Path]::GetFullPath((Join-Path $parent "v3-archunit-$([Guid]::NewGuid().ToString('N'))"))
if (-not $fixture.StartsWith($parent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture.' }
$profile = Join-Path $fixture 'profile'
$runner = Join-Path $package 'scripts/Invoke-V3.ps1'
$output = 'generated'
$utf8 = [Text.UTF8Encoding]::new($false)

function Write-Text([string] $relative, [string] $content) {
    $path = Join-Path $fixture $relative
    [void] [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
    [IO.File]::WriteAllText($path, $content, $utf8)
}
function Write-Json([string] $relative, [object] $value) { Write-Text $relative (($value | ConvertTo-Json -Depth 30) + "`n") }
function Assert-Run([int] $expected, [string[]] $arguments, [string] $label) {
    $result = @(& pwsh -NoProfile -File $runner -ProfileDirectory $profile -TargetRoot $fixture -OutputDirectory $output -LockMode Update -LockRoot (Join-Path $fixture 'locks') @arguments 2>&1)
    if ($LASTEXITCODE -ne $expected) { throw "$label expected exit $expected, got ${LASTEXITCODE}: $($result -join ' | ')" }
    Write-Host "PASS $label"
}
function Read-Report { return Get-Content -LiteralPath (Join-Path $fixture 'artifacts/guards/v3-assembly.json') -Raw | ConvertFrom-Json }

try {
    [void] [IO.Directory]::CreateDirectory($parent)
    # The fixture lives inside a host repository; keep host central package management from applying to its projects.
    Write-Text 'Directory.Packages.props' "<Project><PropertyGroup><ManagePackageVersionsCentrally>false</ManagePackageVersionsCentrally></PropertyGroup></Project>`n"
    Copy-Item -LiteralPath (Join-Path $package 'examples/minimal') -Destination $profile -Recurse
    Write-Text 'src/Target/Target.csproj' '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>'
    Write-Text 'src/Target/Target.cs' 'namespace Demo.Target; public sealed class Forbidden { }'
    Write-Text 'src/App/App.csproj' '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup><ItemGroup><ProjectReference Include="../Target/Target.csproj" /></ItemGroup></Project>'
    Write-Text 'src/App/App.cs' 'namespace Demo.App; public sealed class Allowed { }'
    Write-Text 'src/Ports/Ports.csproj' '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>'
    Write-Text 'src/Ports/Port.cs' 'namespace Demo.Ports; public interface IPort { }'
    Write-Text 'src/Adapters/Adapters.csproj' '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup><ItemGroup><ProjectReference Include="../Ports/Ports.csproj" /></ItemGroup></Project>'
    Write-Text 'src/Adapters/Adapter.cs' 'namespace Demo.Adapters.Inbound; public sealed class Adapter : Demo.Ports.IPort { }'
    $techPath = Join-Path $profile 'tech-stack.json'
    $tech = Get-Content -LiteralPath $techPath -Raw | ConvertFrom-Json -AsHashtable
    $tech.assemblyGate = [ordered]@{ buildTarget = 'src/App/App.csproj'; configuration = 'Debug'; assemblies = @(
        [ordered]@{ projectPath = 'src/App/App.csproj'; assemblyPath = 'src/App/bin/Debug/net10.0/App.dll'; assemblyName = 'App' },
        [ordered]@{ projectPath = 'src/Target/Target.csproj'; assemblyPath = 'src/Target/bin/Debug/net10.0/Target.dll'; assemblyName = 'Target' },
        [ordered]@{ projectPath = 'src/Ports/Ports.csproj'; assemblyPath = 'src/Ports/bin/Debug/net10.0/Ports.dll'; assemblyName = 'Ports' },
        [ordered]@{ projectPath = 'src/Adapters/Adapters.csproj'; assemblyPath = 'src/Adapters/bin/Debug/net10.0/Adapters.dll'; assemblyName = 'Adapters' }
    ) }
    Write-Json 'profile/tech-stack.json' $tech
    $dep = [ordered]@{ formatVersion = 1; id = 'ARCH.DEP'; title = 'App compiled types cannot use Target'; kind = 'forbidden-type-dependency'; enforcement = 'blocking'; coverage = 'partial'; authority = 'Synthetic fixture'; appliesTo = @('src/App/**'); sourceAssembly = 'App'; sourceNamespace = 'Demo.App'; forbiddenAssembly = 'Target'; forbiddenNamespace = 'Demo.Target'; minimumMatches = 1 }
    $port = [ordered]@{ formatVersion = 1; id = 'ARCH.PORT'; title = 'Inbound owns the public port implementation'; kind = 'interface-implementation-location'; enforcement = 'blocking'; coverage = 'partial'; authority = 'Synthetic fixture'; appliesTo = @('src/Adapters/**'); interfaceAssembly = 'Ports'; interfaceType = 'Demo.Ports.IPort'; implementationAssembly = 'Adapters'; implementationNamespace = 'Demo.Adapters.Inbound'; minimumMatches = 1 }
    Write-Json 'profile/rules/ARCH.DEP.json' $dep
    Write-Json 'profile/rules/ARCH.PORT.json' $port
    Assert-Run 0 @('-Mode', 'Validate') 'assembly profile validates'
    Assert-Run 0 @('-Mode', 'Generate') 'optional ArchUnitNET project generates'
    Assert-Run 0 @('-Mode', 'Check') 'generated bytes match'
    Assert-Run 0 @('-Mode', 'Test') 'compliant compiled architecture passes'
    $report = Read-Report
    if ($report.status -ne 'passed' -or $report.loadedAssemblies.Count -ne 4 -or $report.profileInputSha256.Length -ne 64 -or @($report.rules | Where-Object status -ne 'passed').Count -ne 0) { throw 'Expected complete passing assembly evidence.' }
    $projectRulePath = Join-Path $profile 'rules/ARCH.SAMPLE.json'
    $originalProjectRule = [IO.File]::ReadAllText($projectRulePath)
    $projectRule = $originalProjectRule | ConvertFrom-Json -AsHashtable
    $projectRule.forbiddenTargetPattern = '**/Target/*.csproj'
    $projectRule.negativeFixture.referenceInclude = '../Target/Target.csproj'
    Write-Json 'profile/rules/ARCH.SAMPLE.json' $projectRule
    Assert-Run 0 @('-Mode', 'Generate') 'project-only negative regenerates'
    Assert-Run 1 @('-Mode', 'Test') 'unused forbidden ProjectReference still fails project detector'
    if ((Read-Report).status -ne 'passed') { throw 'Compiled detector claimed an unused project reference violation.' }
    [IO.File]::WriteAllText($projectRulePath, $originalProjectRule, $utf8)
    Assert-Run 0 @('-Mode', 'Generate') 'restore independent project rule'
    Write-Text 'src/App/App.cs' 'namespace Demo.App; public sealed class BadUse { public Demo.Target.Forbidden Value { get; } = new(); }'
    Assert-Run 1 @('-Mode', 'Test') 'compiled forbidden dependency fails'
    $report = Read-Report
    if ($report.status -ne 'failed' -or @($report.rules | Where-Object { $_.ruleId -eq 'ARCH.DEP' -and $_.status -eq 'violated' }).Count -ne 1) { throw 'Missing type-dependency evidence.' }
    Write-Text 'src/App/App.cs' 'namespace Demo.App; public sealed class Allowed { }'
    Write-Text 'src/Adapters/Adapter.cs' 'namespace Demo.Adapters.Other; public sealed class Adapter : Demo.Ports.IPort { }'
    Assert-Run 1 @('-Mode', 'Test') 'misplaced interface implementation fails'
    $report = Read-Report
    if (@($report.rules | Where-Object { $_.ruleId -eq 'ARCH.PORT' -and $_.status -eq 'violated' }).Count -ne 1) { throw 'Missing implementation-location evidence.' }
    Write-Text 'src/Adapters/Adapter.cs' 'namespace Demo.Adapters.Inbound; public sealed class Adapter : Demo.Ports.IPort { }'
    $dep.sourceNamespace = 'Demo.Missing'
    Write-Json 'profile/rules/ARCH.DEP.json' $dep
    Assert-Run 0 @('-Mode', 'Generate') 'zero-match rule regenerates'
    Assert-Run 1 @('-Mode', 'Test') 'zero source matches fail closed'
    $dep.sourceNamespace = 'Demo.App'
    Write-Json 'profile/rules/ARCH.DEP.json' $dep
    $tech.assemblyGate.assemblies[1].assemblyPath = 'src/Target/bin/Debug/net10.0/Missing/Target.dll'
    Write-Json 'profile/tech-stack.json' $tech
    Assert-Run 0 @('-Mode', 'Generate') 'missing-assembly manifest regenerates'
    Assert-Run 1 @('-Mode', 'Test') 'missing expected assembly fails closed'
    Remove-Item -LiteralPath (Join-Path $profile 'rules/ARCH.DEP.json') -Force
    Remove-Item -LiteralPath (Join-Path $profile 'rules/ARCH.PORT.json') -Force
    $tech.Remove('assemblyGate')
    Write-Json 'profile/tech-stack.json' $tech
    Assert-Run 0 @('-Mode', 'Generate') 'remove optional detector cleanly'
    Assert-Run 0 @('-Mode', 'Check') 'project-only generation remains exact'
    if ([IO.File]::Exists((Join-Path $fixture 'generated/AssemblyGuardTests.cs')) -or [IO.File]::ReadAllText((Join-Path $fixture 'generated/GuardV3.Tests.csproj')).Contains('TngTech.ArchUnitNET')) { throw 'Unselected detector left a generated dependency.' }
    Assert-Run 0 @('-Mode', 'Test') 'project-only profile still passes'
    Write-Host 'V3 ArchUnitNET synthetic integration tests passed.'
}
finally {
    if ([IO.Directory]::Exists($fixture)) {
        $resolved = [IO.Path]::GetFullPath($fixture)
        if (-not $resolved.StartsWith($parent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture cleanup.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
