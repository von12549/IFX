[CmdletBinding()]
param()

# Positive and negative fixtures for trusted-base/Test-IFXDomainAuthorityCandidates.ps1 (Plan 06 §12.6, D18).
# Base is this repository; each case mutates a head candidate copy of the registered domain authorities.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repository = [IO.Path]::GetFullPath((Join-Path $package '../../..'))
$artifacts = [IO.Path]::GetFullPath((Join-Path $repository 'artifacts/guards'))
$fixture = [IO.Path]::GetFullPath((Join-Path $artifacts "v3-ifx-authority-candidates-$([Guid]::NewGuid().ToString('N'))"))
if (-not $fixture.StartsWith($artifacts + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture path.' }
$checker = Join-Path $package 'trusted-base/Test-IFXDomainAuthorityCandidates.ps1'
$authorityRegistryCandidates = @(@('policy/authorities.json', 'shared/authorities/authorities.json') | ForEach-Object { Join-Path $package $_ } | Where-Object { [IO.File]::Exists($_) })
if ($authorityRegistryCandidates.Count -ne 1) { throw "Exactly one legacy or shared authority registry must exist; found $($authorityRegistryCandidates.Count)." }
$registry = Get-Content -LiteralPath $authorityRegistryCandidates[0] -Raw | ConvertFrom-Json
$utf8 = [Text.UTF8Encoding]::new($false)

function Reset-Head {
    if ([IO.Directory]::Exists($fixture)) { [IO.Directory]::Delete($fixture, $true) }
    foreach ($authority in $registry.domainAuthorities) {
        $destination = Join-Path $fixture $authority.path
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
        [IO.File]::Copy((Join-Path $repository $authority.path), $destination, $true)
    }
}

function Invoke-Case([string] $label, [int] $expected, [string] $relative, [scriptblock] $mutate, [string] $expectText) {
    Reset-Head
    if ($mutate) {
        $path = Join-Path $fixture $relative
        $document = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $result = & $mutate $document $path
        if ($result -ne 'written') { [IO.File]::WriteAllText($path, ($document | ConvertTo-Json -Depth 100), $utf8) }
    }
    $output = @(& pwsh -NoProfile -File $checker -TargetRoot $fixture -BaseRepository $repository -ReportPath 'report.json' 2>&1) -join ' | '
    if ($LASTEXITCODE -ne $expected) { throw "$label expected exit $expected, got ${LASTEXITCODE}: $output" }
    if ($expectText -and -not $output.Contains($expectText, [StringComparison]::Ordinal)) { throw "$label did not report '$expectText': $output" }
    Write-Host "PASS $label"
}

$catalog = 'docs/architecture/review/gates/G03/contract-event-catalog.yaml'
$bypass = 'docs/architecture/review/policies/plan04/tenant-query-bypass-registry.json'
$criticality = 'deployment/g04/dependency-criticality-catalog.json'
try {
    Invoke-Case 'unchanged candidates pass' 0 $null $null 'passed (0 changed)'
    Invoke-Case 'reformatted JSON is equivalent' 0 $criticality { param($d, $p) [IO.File]::WriteAllText($p, ($d | ConvertTo-Json -Depth 100 -Compress), $utf8); 'written' } 'passed'
    Invoke-Case 'new consumer declaration with its owner passes' 0 $catalog { param($d) $consumer = $d.consumers[0].Clone(); $consumer.id = 'fixture-consumer'; $consumer.owner = 'fixture-owner'; $d.consumers += $consumer } 'passed (1 changed)'
    Invoke-Case 'reordered keyed declarations pass' 0 $catalog { param($d) [array]::Reverse($d.publicSurface) } 'passed (1 changed)'
    Invoke-Case 'target declaration content change passes' 0 'deployment/g04/deployment-unit-catalog.json' { param($d) $d.units[0].scaling = 'fixture-scaling' } 'passed (1 changed)'
    Invoke-Case 'new dependency with criticality passes' 0 $criticality { param($d) $dependency = $d.dependencies[0].Clone(); $dependency.dependencyId = 'fixture-dependency'; $d.dependencies += $dependency } 'passed (1 changed)'
    Invoke-Case 'removing a bypass entry narrows the exception' 0 $bypass { param($d) $d.entries = @($d.entries | Select-Object -Skip 1) } 'passed (1 changed)'
    Invoke-Case 'catalog mode change fails' 1 $catalog { param($d) $d.mode = 'enforced-fixture' } 'g03-contract-event-catalog/mode [governing-policy] governing-policy-change'
    Invoke-Case 'existing protocol lifecycle change fails' 1 $catalog { param($d) $d.protocols[0].lifecycle = 'Deprecated' } "g03-contract-event-catalog/protocols/$((Get-Content -LiteralPath (Join-Path $repository $catalog) -Raw | ConvertFrom-Json).protocols[0].identity)/lifecycle [governing-policy] governing-policy-change"
    Invoke-Case 'existing module owner change fails' 1 $catalog { param($d) $d.modules[0].owner = 'someone-else' } 'governing-policy-change'
    Invoke-Case 'new waiver fails closed' 1 $catalog { param($d) $d.waivers += [ordered]@{ id = 'fixture-waiver' } } 'g03-contract-event-catalog/waivers [exception-authorization] exception-expansion'
    Invoke-Case 'changed field exception fails closed' 1 $catalog { param($d) $d.fieldExceptions[0]['fixture'] = 'widened' } 'exception-expansion'
    Invoke-Case 'new bypass entry fails closed' 1 $bypass { param($d) $entry = $d.entries[0].Clone(); $entry.id = 'fixture-bypass'; $d.entries += $entry } 'plan04-tenant-query-bypass-registry [exception-authorization] exception-expansion'
    Invoke-Case 'extended bypass expiry fails closed' 1 $bypass { param($d) $d.entries[0].expiresAt = '2099-12-31' } 'exception-expansion'
    Invoke-Case 'existing dependency criticality change fails' 1 $criticality { param($d) $d.dependencies[0].criticality = 'degraded' } 'g04-dependency-criticality/dependencies/static-configuration/criticality [governing-policy]'
    Invoke-Case 'derived runtime manifest allowed roles change fails' 1 'deployment/g04/release-runtime-manifest.json' { param($d) $d.hostArtifact.allowedRoles += 'fixture-role' } 'g04-release-runtime-manifest/hostArtifact/allowedRoles [governing-policy]'
    Invoke-Case 'governing policy file change fails' 1 'deployment/g04/backpressure-policy.json' { param($d) $d['owner'] = 'fixture-owner' } 'g04-backpressure-policy [governing-policy] governing-policy-change'
    Invoke-Case 'migration review exception added fails' 1 'deployment/migration-safety-policy.json' { param($d) $d.reviewedMigrations += [ordered]@{ migrationId = 'fixture' } } 'database-migration-safety-policy/reviewedMigrations [exception-authorization]'
    Invoke-Case 'duplicate declared identity fails' 1 $catalog { param($d) $d.modules += $d.modules[0] } 'identity-invalid'
    Invoke-Case 'removed governing authority fails' 1 'deployment/g04/failure-matrix.json' { param($d, $p) [IO.File]::Delete($p); 'written' } 'g04-failure-matrix [governing-policy] authority-removed'
    Invoke-Case 'invalid JSON candidate fails' 1 'deployment/g04/failure-matrix.json' { param($d, $p) [IO.File]::WriteAllText($p, '{ not json', $utf8); 'written' } 'invalid-json'
    Write-Host 'IFX domain authority candidate tests passed.'
}
finally {
    if ([IO.Directory]::Exists($fixture)) { [IO.Directory]::Delete($fixture, $true) }
}
