[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$fixtureParent = [IO.Path]::GetFullPath((Join-Path $root 'artifacts/guards'))
$fixture = [IO.Path]::GetFullPath((Join-Path $fixtureParent "domain-fixture-$([Guid]::NewGuid().ToString('N'))"))
if (-not $fixture.StartsWith($fixtureParent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe Domain fixture path.' }
$relative = [IO.Path]::GetRelativePath($root, $fixture).Replace('\', '/')
$guard = Join-Path $root 'scripts/guards/Invoke-DomainAssemblyGuard.ps1'

function Assert-GuardStatus {
    param([int] $ExpectedExit, [string] $ExpectedStatus, [string] $Assembly)
    $report = "$relative/result.json"
    $output = @(& pwsh -NoProfile -File $guard -RepositoryRoot $root -PolicyPath "$relative/policy.json" -AssemblyPaths "$relative/$Assembly" -ReportPath $report 2>&1)
    if ($LASTEXITCODE -ne $ExpectedExit) { throw "Expected exit $ExpectedExit, got ${LASTEXITCODE}: $($output -join ' | ')" }
    $result = Get-Content -LiteralPath (Join-Path $fixture 'result.json') -Raw | ConvertFrom-Json
    if ($result.status -ne $ExpectedStatus) { throw "Expected $ExpectedStatus, got $($result.status): $($result.reason)" }
    return $result
}

$passed = $false
try {
    [void] [IO.Directory]::CreateDirectory($fixture)
    $allowed = Join-Path $fixture 'allowed.dll'
    $forbidden = Join-Path $fixture 'forbidden.dll'
    $good = Join-Path $fixture 'good-domain.dll'
    $bad = Join-Path $fixture 'bad-domain.dll'
    Add-Type -TypeDefinition 'public class AllowedFixtureType {}' -OutputAssembly $allowed -ErrorAction Stop
    Add-Type -TypeDefinition 'public class ForbiddenFixtureType {}' -OutputAssembly $forbidden -ErrorAction Stop
    Add-Type -TypeDefinition 'public class GoodDomainFixture { public AllowedFixtureType Value { get; set; } }' -ReferencedAssemblies $allowed -OutputAssembly $good -ErrorAction Stop
    Add-Type -TypeDefinition 'public class BadDomainFixture { public ForbiddenFixtureType Value { get; set; } }' -ReferencedAssemblies $forbidden -OutputAssembly $bad -ErrorAction Stop
    $allowedName = [Reflection.AssemblyName]::GetAssemblyName($allowed).Name
    $forbiddenName = [Reflection.AssemblyName]::GetAssemblyName($forbidden).Name
    $policy = @{ allowedReferences = @{ Domain = @($allowedName) } } | ConvertTo-Json -Depth 10
    [IO.File]::WriteAllText((Join-Path $fixture 'policy.json'), $policy)

    $goodResult = Assert-GuardStatus 0 'pass' 'good-domain.dll'
    if (@($goodResult.checks[0].referencedAssemblies | Where-Object { $_ -eq $allowedName }).Count -ne 1) { throw 'Positive fixture did not actually reference the allowed assembly.' }
    $badResult = Assert-GuardStatus 1 'fail' 'bad-domain.dll'
    if (@($badResult.checks[0].forbiddenReferences | Where-Object { $_ -eq $forbiddenName }).Count -ne 1) { throw 'Negative fixture was not rejected for its compiled forbidden reference.' }
    [void] (Assert-GuardStatus 1 'blocked' 'missing-domain.dll')
    $passed = $true
    Write-Host 'Domain assembly guard tests passed.'
}
finally {
    if ($passed -and [IO.Directory]::Exists($fixture)) {
        $verified = [IO.Path]::GetFullPath($fixture)
        if (-not $verified.StartsWith($fixtureParent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe Domain fixture cleanup path.' }
        Remove-Item -LiteralPath $verified -Recurse -Force
    }
    elseif (-not $passed) { Write-Warning "Failed Domain fixture retained at $fixture" }
}
