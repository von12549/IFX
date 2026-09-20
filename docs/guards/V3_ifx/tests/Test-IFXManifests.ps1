[CmdletBinding()]
param()

# Positive and negative fixtures for scripts/Invoke-IFXManifestCheck.ps1 (Plan 06 P1.5).

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repository = [IO.Path]::GetFullPath((Join-Path $package '../../..'))
$artifacts = [IO.Path]::GetFullPath((Join-Path $repository 'artifacts/guards'))
$fixture = [IO.Path]::GetFullPath((Join-Path $artifacts "v3-ifx-manifests-$([Guid]::NewGuid().ToString('N'))"))
if (-not $fixture.StartsWith($artifacts + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe fixture path.' }
$utf8 = [Text.UTF8Encoding]::new($false)

function Copy-Into([string] $source, [string] $relative) {
    $destination = Join-Path $fixture $relative
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
    [IO.File]::Copy($source, $destination, $true)
}

function Invoke-Case([string] $label, [int] $expected, [string] $relative, [scriptblock] $mutate, [string] $expectText) {
    $path = if ($relative) { Join-Path $fixture $relative } else { $null }
    $original = if ($path -and [IO.File]::Exists($path)) { [IO.File]::ReadAllBytes($path) } else { $null }
    try {
        if ($mutate) {
            if ($path -and $relative.EndsWith('.json') -and [IO.File]::Exists($path)) {
                $document = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable -Depth 50
                & $mutate $document
                [IO.File]::WriteAllText($path, ($document | ConvertTo-Json -Depth 50) + "`n", $utf8)
            } else { & $mutate $path }
        }
        $output = @(& pwsh -NoProfile -File (Join-Path $fixture 'docs/guards/V3_ifx/scripts/Invoke-IFXManifestCheck.ps1') -TargetRoot $fixture 2>&1) -join ' | '
        if ($LASTEXITCODE -ne $expected) { throw "$label expected exit $expected, got ${LASTEXITCODE}: $output" }
        if ($expectText -and -not $output.Contains($expectText, [StringComparison]::Ordinal)) { throw "$label did not report '$expectText': $output" }
        Write-Host "PASS $label"
    }
    finally {
        if ($path) {
            if ($null -ne $original) { [IO.File]::WriteAllBytes($path, $original) } elseif ([IO.File]::Exists($path)) { [IO.File]::Delete($path) }
        }
    }
}

try {
    foreach ($file in Get-ChildItem -LiteralPath $package -Recurse -File) {
        $relative = [IO.Path]::GetRelativePath($package, $file.FullName).Replace('\', '/')
        if ($relative -match '(^|/)(bin|obj)/' -or $relative.StartsWith('analysis/ifx/refactor-baseline/ci-evidence/')) { continue }
        Copy-Into $file.FullName "docs/guards/V3_ifx/$relative"
    }
    Copy-Into (Join-Path $repository '.github/workflows/v3-ifx-guardrails.yml') '.github/workflows/v3-ifx-guardrails.yml'
    Copy-Into (Join-Path $repository '.github/CODEOWNERS') '.github/CODEOWNERS'
    foreach ($relative in @('Directory.Build.props', 'Directory.Packages.props', 'docs/Directory.Packages.props')) { Copy-Into (Join-Path $repository $relative) $relative }
    # Domain authority files are target data read by the registry lint (Plan 06 D18).
    $registry = Get-Content -LiteralPath (Join-Path $package 'policy/authorities.json') -Raw | ConvertFrom-Json
    foreach ($authority in $registry.domainAuthorities) { Copy-Into (Join-Path $repository $authority.path) $authority.path }
    $v3Roots = @('docs/guards/V3/build', 'docs/guards/V3/contracts', 'docs/guards/V3/tests', 'docs/guards/V3/templates', 'docs/guards/V3/scripts', 'docs/guards/V3/hooks', 'docs/guards/V3/stages')
    if ([IO.Directory]::Exists((Join-Path $repository 'docs/guards/V3/commands'))) { $v3Roots += 'docs/guards/V3/commands' }
    foreach ($root in $v3Roots) {
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repository $root) -Recurse -File) {
            $relative = [IO.Path]::GetRelativePath($repository, $file.FullName).Replace([IO.Path]::DirectorySeparatorChar, '/')
            if ($relative -match '(^|/)(bin|obj)/') { continue }
            Copy-Into $file.FullName $relative
        }
    }

    $stagePost = 'docs/guards/V3_ifx/stages/post/stage.json'
    $commands = 'docs/guards/V3_ifx/shared/commands.json'
    $tcb = 'docs/guards/V3_ifx/shared/trusted-components.json'
    $system = 'docs/guards/V3_ifx/guard-system.json'
    $usesCommandLayout = [IO.File]::Exists((Join-Path $fixture 'docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1'))
    $orchestrator = if ($usesCommandLayout) { 'docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1' } else { 'docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails.ps1' }
    $legacyQualityRoot = 'docs/guards/V3_ifx/quality'
    $stageQualityRoot = 'docs/guards/V3_ifx/stages/post/gates/quality'
    $qualityFiles = @('Invoke-IFXAssemblyGuard.ps1', 'Invoke-IFXPackageAudit.ps1', 'Invoke-IFXQuality.ps1')
    $legacyQualityComplete = @($qualityFiles | Where-Object { -not [IO.File]::Exists((Join-Path $fixture "$legacyQualityRoot/$_")) }).Count -eq 0
    $stageQualityComplete = @($qualityFiles | Where-Object { -not [IO.File]::Exists((Join-Path $fixture "$stageQualityRoot/$_")) }).Count -eq 0
    if ($legacyQualityComplete -eq $stageQualityComplete) { throw 'Quality must have exactly one complete legacy or stage-owned layout.' }
    $qualityRoot = if ($stageQualityComplete) { $stageQualityRoot } else { $legacyQualityRoot }
    $legacySpecializedRoot = 'docs/guards/V3_ifx/specialized'
    $stageSpecializedRoot = 'docs/guards/V3_ifx/stages/post/gates/specialized'
    $specializedFiles = @('Invoke-IFXSpecialized.ps1', 'contracts/detector-result.schema.json', 'contracts/fixture.schema.json', 'scripts/Test-Plan04ExtractionPolicy.ps1')
    $legacySpecializedComplete = @($specializedFiles | Where-Object { -not [IO.File]::Exists((Join-Path $fixture "$legacySpecializedRoot/$_")) }).Count -eq 0
    $stageSpecializedComplete = @($specializedFiles | Where-Object { -not [IO.File]::Exists((Join-Path $fixture "$stageSpecializedRoot/$_")) }).Count -eq 0
    if ($legacySpecializedComplete -eq $stageSpecializedComplete) { throw 'Specialized gates must have exactly one complete legacy or stage-owned layout.' }
    $specializedRoot = if ($stageSpecializedComplete) { $stageSpecializedRoot } else { $legacySpecializedRoot }

    Invoke-Case 'current manifests pass' 0
    Invoke-Case 'stage declaring a command-owned field fails' 1 $stagePost { param($d) $d['entryPoint'] = $orchestrator } "command-owned field 'entryPoint'"
    Invoke-Case 'command declaring a stage-owned field fails' 1 $commands { param($d) $d.commands[0]['dependencies'] = @('pre') } "stage-owned field 'dependencies'"
    Invoke-Case 'stage referencing an unknown command fails' 1 $stagePost { param($d) $d.commands += 'ifx-missing-command' } "unknown command 'ifx-missing-command'"
    Invoke-Case 'command claiming an unlisted stage fails' 1 $commands { param($d) ($d.commands | Where-Object { $_.id -eq 'ifx-quality' }).stages += 'diff' } "claims stage 'diff'"
    Invoke-Case 'missing gate for a required check fails' 1 $stagePost { param($d) $d.gates = @($d.gates | Where-Object { $_.id -ne 'v3-quality-frontend' }) } "Required check 'v3-quality-frontend'"
    Invoke-Case 'duplicate gate fails' 1 $stagePost { param($d) $d.gates += ($d.gates | Where-Object { $_.id -eq 'v3-architecture' }) } "Required check 'v3-architecture' must be declared by exactly one stage gate (found 2)"
    Invoke-Case 'gate that is not a required check fails' 1 $stagePost { param($d) $extra = ($d.gates[0] | ConvertTo-Json -Depth 10 | ConvertFrom-Json -AsHashtable); $extra.id = 'v3-extra'; $d.gates += $extra } "Stage gate 'v3-extra' is not a required check"
    Invoke-Case 'invalid trust contract type fails schema' 1 $stagePost { param($d) $d.gates[0].trustContract.type = 'trusted' } 'Schema validation failed'
    Invoke-Case 'verdict-chain script outside TCB fails' 1 $tcb { param($d) ($d.components | Where-Object { $_.id -eq 'tcb.engine.quality' }).paths = @("$qualityRoot/Invoke-IFXQuality.ps1") } "Verdict-chain script is outside the trusted component manifest: $qualityRoot/Invoke-IFXAssemblyGuard.ps1"
    Invoke-Case 'manifest removing itself from protection fails' 1 $tcb { param($d) ($d.components | Where-Object { $_.id -eq 'tcb.manifest' }).paths = @('docs/guards/V3_ifx/stages/') } 'not self-protecting'
    Invoke-Case 'overlapping components fail' 1 $tcb { param($d) ($d.components | Where-Object { $_.id -eq 'tcb.engine.quality' }).paths += $orchestrator } 'overlap'
    Invoke-Case 'planned component claiming paths fails' 1 $tcb { param($d) $d.components += [ordered]@{ id = 'tcb.future-component'; type = 'future'; status = 'planned'; paths = @('Directory.Build.props'); validationSuite = @('future'); parityContract = 'future'; allowedChange = 'change-trusted-base' } } "Planned component 'tcb.future-component'"
    Invoke-Case 'workflow script added outside TCB fails' 1 '.github/workflows/v3-ifx-guardrails.yml' { param($p) [IO.File]::AppendAllText($p, "      - run: ./docs/guards/V3_ifx/scripts/Invoke-Untrusted.ps1`n") } 'Workflow references a missing script: docs/guards/V3_ifx/scripts/Invoke-Untrusted.ps1'
    Invoke-Case 'IFX command redirecting to a forked V3 runner fails' 1 $commands { param($d) ($d.commands | Where-Object { $_.id -eq 'v3-runner' }).entryPoint = 'docs/guards/V3_ifx/scripts/Invoke-V3.ps1' } "Command 'v3-runner' must reference the canonical V3 entry point"
    Invoke-Case 'IFX Diff without explicit overlay protection fails' 1 $orchestrator { param($p) [IO.File]::WriteAllText($p, ([IO.File]::ReadAllText($p).Replace(",'-ProtectionPath',(Join-Path `$packageRoot 'stages/diff/protection.json')", '')), $utf8) } 'IFX Diff must pass the overlay protection configuration to canonical V3.'
    Invoke-Case 'stage listed without manifest fails' 1 $system { param($d) $d.stages = @($d.stages | Where-Object { $_ -ne 'diff' }) } "Stage manifest 'diff' is not listed"
    Invoke-Case 'compatibility entry for a missing path fails' 1 $system { param($d) $d.compatibility.entries[0].legacyPath = 'docs/guards/V3_ifx/scripts/Missing.ps1' } 'missing legacy path'
    $authorities = 'docs/guards/V3_ifx/policy/authorities.json'
    function Get-Gate($document, [string] $id) { return @($document.gates | Where-Object { $_.id -eq $id })[0] }
    Invoke-Case 'engine script reading an unregistered authority fails' 1 "$specializedRoot/scripts/Test-UnregisteredAuthorityProbe.ps1" { param($p) [IO.File]::WriteAllText($p, "Get-Content 'deployment/g04/unregistered-policy.json'`n") } 'reads an unregistered domain authority: deployment/g04/unregistered-policy.json'
    Invoke-Case 'detector reading an undeclared authority fails' 1 $stagePost { param($d) $g = Get-Gate $d 'v3-specialized-g04'; $g.trustContract.inputs = @($g.trustContract.inputs | Where-Object { $_.ref -ne 'authority:g04-failure-matrix' }) } "Gate 'v3-specialized-g04' detectors read domain authority 'g04-failure-matrix' without declaring it"
    Invoke-Case 'declared authority that detectors do not read fails' 1 $stagePost { param($d) (Get-Gate $d 'v3-specialized-g03').trustContract.inputs += [ordered]@{ ref = 'authority:g05-open-items'; source = 'head-candidate' } } "declares domain authority 'g05-open-items' that its detectors do not read"
    Invoke-Case 'head authority sourced from base fails' 1 $stagePost { param($d) @((Get-Gate $d 'v3-specialized-g03').trustContract.inputs | Where-Object { $_.ref -eq 'authority:g03-contract-event-catalog' })[0].source = 'base' } 'must come from head-candidate, not base'
    Invoke-Case 'derived projection sourced as head candidate fails' 1 $stagePost { param($d) @((Get-Gate $d 'v3-specialized-g03').trustContract.inputs | Where-Object { $_.ref -eq 'authority:g03-sync-api-snapshot' })[0].source = 'head-candidate' } 'must come from derived-candidate, not head-candidate'
    Invoke-Case 'unknown authority reference fails' 1 $stagePost { param($d) (Get-Gate $d 'v3-specialized-g05').trustContract.inputs += [ordered]@{ ref = 'authority:g05-missing'; source = 'head-candidate' } } 'unknown domain authority: g05-missing'
    Invoke-Case 'projection consumed without its authority fails' 1 $stagePost { param($d) $g = Get-Gate $d 'v3-architecture'; $g.trustContract.inputs = @($g.trustContract.inputs | Where-Object { $_.ref -ne 'authority:g05-context-protocol' }) } "without declaring its authority 'g05-context-protocol'"
    Invoke-Case 'gate without trust inputs fails schema' 1 $stagePost { param($d) (Get-Gate $d 'v3-quality-frontend').trustContract.Remove('inputs') } 'Schema validation failed'
    Invoke-Case 'pointer role matching nothing fails' 1 $authorities { param($d) @($d.domainAuthorities | Where-Object { $_.id -eq 'g03-contract-event-catalog' })[0].pointerRoles += [ordered]@{ pointer = '/missingPolicy'; role = 'governing-policy' } } "pointer /missingPolicy matches nothing"
    Invoke-Case 'unknown authority role fails schema' 1 $authorities { param($d) $d.domainAuthorities[0].defaultRole = 'advisory' } 'Schema validation failed: docs/guards/V3_ifx/policy/authorities.json'
    Invoke-Case 'unregistered projection source fails' 1 $authorities { param($d) $d.domainAuthorities = @($d.domainAuthorities | Where-Object { $_.id -ne 'g04-failure-matrix' }) } 'Policy projection source is not a registered domain authority: deployment/g04/failure-matrix.json'
    Invoke-Case 'wildcard pointer without an array key fails' 1 $authorities { param($d) $a = @($d.domainAuthorities | Where-Object { $_.id -eq 'g04-dependency-criticality' })[0]; $a.Remove('arrayKeys') } 'needs an arrayKeys entry for /dependencies'
    Invoke-Case 'array key that is not unique fails' 1 $authorities { param($d) @($d.domainAuthorities | Where-Object { $_.id -eq 'g04-dependency-criticality' })[0].arrayKeys[0].key = 'criticality' } "arrayKeys /dependencies is not an array of objects with a unique string 'criticality'"
    Invoke-Case 'invalid Diff protection configuration fails' 1 'docs/guards/V3_ifx/stages/diff/protection.json' { param($d) $d.protectedPaths = @('../outside') } 'Schema validation failed: docs/guards/V3_ifx/stages/diff/protection.json'
    $protectionFixture = Join-Path $fixture 'docs/guards/V3_ifx/stages/diff/protection.json'
    $protectionBytes = [IO.File]::ReadAllBytes($protectionFixture)
    try { Invoke-Case 'missing Diff protection configuration fails' 1 $null { [IO.File]::Delete($protectionFixture) } 'Diff protection configuration is missing' }
    finally { [IO.File]::WriteAllBytes($protectionFixture, $protectionBytes) }
    Invoke-Case 'unregistered policy file fails' 1 'docs/guards/V3_ifx/policy/fixture-extra.json' { param($p) [IO.File]::WriteAllText($p, "{}`n", $utf8) } 'Policy or configuration file is not registered in shared/policy-config.json: docs/guards/V3_ifx/policy/fixture-extra.json'
    Invoke-Case 'schema field without a monotonicity declaration fails' 1 'docs/guards/V3_ifx/contracts/rule.schema.json' { param($d) $d.properties['fixtureField'] = [ordered]@{ type = 'string' } } 'Schema field without a monotonicity declaration: docs/guards/V3_ifx/contracts/rule.schema.json#/properties/fixtureField'
    Invoke-Case 'policy registry claiming a derived projection fails' 1 'docs/guards/V3_ifx/shared/policy-config.json' { param($d) @($d.entries | Where-Object { $_.id -eq 'layerguard-policy' })[0].paths += 'docs/guards/V3_ifx/policy/g05/context-protocol-v1.json' } "Policy registry entry 'layerguard-policy' claims derived projection target docs/guards/V3_ifx/policy/g05/context-protocol-v1.json"
    Invoke-Case 'policy registry claiming an authorization record fails' 1 'docs/guards/V3_ifx/shared/policy-config.json' { param($d) @($d.entries | Where-Object { $_.id -eq 'diff-protection' })[0].paths += 'docs/guards/V3_ifx/stages/diff/authorizations/fixture.json' } "Policy registry entry 'diff-protection' claims excluded path docs/guards/V3_ifx/stages/diff/authorizations/fixture.json"
    Write-Host 'IFX manifest tests passed.'
}
finally {
    if ([IO.Directory]::Exists($fixture)) { [IO.Directory]::Delete($fixture, $true) }
}
