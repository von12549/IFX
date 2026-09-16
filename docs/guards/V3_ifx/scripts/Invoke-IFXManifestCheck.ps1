[CmdletBinding()]
param(
    [string] $TargetRoot,
    [string] $PackagePath = 'docs/guards/V3_ifx',
    [string] $WorkflowPath = '.github/workflows/v3-ifx-guardrails.yml'
)

# Plan 06 P1.5 manifest verifier: schema validity, single field owner between stage.json and commands.json,
# referential integrity, one gate per required check, and a self-protecting trusted component manifest
# that covers every script on a CI verdict chain.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
# Manifests, schemas and verdict-chain scripts belong to the package repository this checker runs from;
# only the workflow is read from the target repository (Plan 06 P2 root separation).
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$targetRepository = if ($TargetRoot) { [IO.Path]::GetFullPath($TargetRoot) } elseif ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { $root }
$package = $PackagePath.Replace('\', '/').TrimEnd('/')
$failures = [Collections.Generic.List[string]]::new()
function Fail([string] $message) { $failures.Add($message) }
function Full([string] $relative) { return (Join-Path $root $relative) }
function Exists([string] $relative) {
    if ($relative.EndsWith('/')) { return [IO.Directory]::Exists((Full $relative)) }
    return [IO.File]::Exists((Full $relative))
}
function Read-Manifest([string] $relative, [string] $schema) {
    $path = Full $relative
    if (-not [IO.File]::Exists($path)) { Fail "Missing manifest: $relative"; return $null }
    try {
        if (-not (Test-Json -Path $path -SchemaFile (Full "$package/contracts/$schema.schema.json") -ErrorAction Stop)) { Fail "Schema validation failed: $relative"; return $null }
    } catch { Fail "Schema validation failed: ${relative}: $($_.Exception.Message)"; return $null }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable -Depth 50
}

$system = Read-Manifest "$package/guard-system.json" 'guard-system'
if ($null -eq $system) { foreach ($failure in $failures) { Write-Host "FAIL $failure" }; exit 1 }
$commands = Read-Manifest $system.manifests.commands 'commands'
$tcb = Read-Manifest $system.manifests.trustedComponents 'trusted-components'

# ---------------------------------------------------------------- stages and field owners
$commandOwned = @('entryPoint', 'inputs', 'outputs', 'evidence', 'mutability', 'requiresExplicitAcceptance', 'platforms', 'stability')
$stageOwned = @('dependencies', 'enforcement', 'executionClass', 'documentation', 'gates')
$stageDocs = [ordered]@{}
$stageRoot = $system.manifests.stages.TrimEnd('/')
if ([IO.Directory]::Exists((Full $stageRoot))) {
    foreach ($directory in (Get-ChildItem -LiteralPath (Full $stageRoot) -Directory | Sort-Object Name)) {
        $relative = "$stageRoot/$($directory.Name)/stage.json"
        if (-not [IO.File]::Exists((Full $relative))) { continue }
        $raw = Get-Content -LiteralPath (Full $relative) -Raw | ConvertFrom-Json -AsHashtable -Depth 50
        foreach ($field in $commandOwned) { if ($raw.ContainsKey($field)) { Fail "Field owner violation: $relative declares command-owned field '$field'" } }
        $doc = Read-Manifest $relative 'stage'
        if ($null -eq $doc) { continue }
        if ($doc.id -ne $directory.Name) { Fail "Stage directory $($directory.Name) declares id '$($doc.id)'" }
        $stageDocs[$doc.id] = $doc
    }
}
$declaredStages = @($system.stages)
foreach ($id in $declaredStages) { if (-not $stageDocs.Contains($id)) { Fail "guard-system.json lists stage '$id' without $stageRoot/$id/stage.json" } }
foreach ($id in $stageDocs.Keys) { if ($id -notin $declaredStages) { Fail "Stage manifest '$id' is not listed in guard-system.json" } }

$commandIds = @()
if ([IO.File]::Exists((Full $system.manifests.commands))) {
    # Field owners are checked on the raw document so the violation is named even when schema validation also fails.
    $rawCommands = Get-Content -LiteralPath (Full $system.manifests.commands) -Raw | ConvertFrom-Json -AsHashtable -Depth 50
    foreach ($entry in @($rawCommands['commands'])) {
        foreach ($field in $stageOwned) { if ($entry -is [Collections.IDictionary] -and $entry.ContainsKey($field)) { Fail "Field owner violation: command '$($entry['id'])' declares stage-owned field '$field'" } }
    }
}
if ($null -ne $commands) {
    $commandIds = @($commands.commands | ForEach-Object { $_.id })
    if (@($commandIds | Select-Object -Unique).Count -ne $commandIds.Count) { Fail 'Command IDs must be unique.' }
    foreach ($command in $commands.commands) {
        if (-not (Exists $command.entryPoint)) { Fail "Command '$($command.id)' entry point is missing: $($command.entryPoint)" }
        foreach ($stage in $command.stages) {
            if (-not $stageDocs.Contains($stage)) { Fail "Command '$($command.id)' references unknown stage '$stage'"; continue }
            if ($command.id -notin @($stageDocs[$stage].commands)) { Fail "Command '$($command.id)' claims stage '$stage' but that stage does not list it" }
        }
    }
}
foreach ($stage in $stageDocs.Values) {
    if ($null -ne $commands) { foreach ($id in $stage.commands) { if ($id -notin $commandIds) { Fail "Stage '$($stage.id)' references unknown command '$id'" } } }
    foreach ($dependency in $stage.dependencies) { if (-not $stageDocs.Contains($dependency)) { Fail "Stage '$($stage.id)' depends on unknown stage '$dependency'" } }
    foreach ($document in $stage.documentation) { if (-not (Exists $document)) { Fail "Stage '$($stage.id)' documentation is missing: $document" } }
}

# ---------------------------------------------------------------- one gate per required check
$jobs = Get-Content -LiteralPath (Full "$package/ci/jobs.json") -Raw | ConvertFrom-Json -AsHashtable
$required = @($jobs.jobs | ForEach-Object { [string]$_.id })
$gateIds = @($stageDocs.Values | ForEach-Object { @($_.gates) } | ForEach-Object { [string]$_.id })
foreach ($id in $required) {
    $count = @($gateIds | Where-Object { $_ -eq $id }).Count
    if ($count -ne 1) { Fail "Required check '$id' must be declared by exactly one stage gate (found $count)" }
}
foreach ($id in ($gateIds | Select-Object -Unique)) { if ($id -notin $required) { Fail "Stage gate '$id' is not a required check in ci/jobs.json" } }

# ---------------------------------------------------------------- trusted components
if ($null -ne $tcb) {
    $owners = @{}
    $activePaths = [Collections.Generic.List[object]]::new()
    foreach ($component in $tcb.components) {
        if ($component.status -eq 'planned' -and @($component.paths).Count -gt 0) { Fail "Planned component '$($component.id)' must not claim existing paths" }
        if ($component.status -eq 'active' -and @($component.paths).Count -eq 0) { Fail "Active component '$($component.id)' has no paths" }
        foreach ($path in $component.paths) {
            if (-not (Exists $path)) { Fail "Component '$($component.id)' path is missing: $path"; continue }
            foreach ($other in $activePaths) {
                $overlap = $path -eq $other.path -or ($other.path.EndsWith('/') -and $path.StartsWith($other.path)) -or ($path.EndsWith('/') -and $other.path.StartsWith($path))
                if ($overlap) { Fail "Components '$($other.id)' and '$($component.id)' overlap on $path" }
            }
            $activePaths.Add([pscustomobject]@{ id = $component.id; path = $path })
        }
    }
    function Get-ComponentFor([string] $path) {
        foreach ($entry in $activePaths) {
            if ($entry.path -eq $path -or ($entry.path.EndsWith('/') -and $path.StartsWith($entry.path))) { return $entry.id }
        }
        return $null
    }
    foreach ($self in @($tcb.manifest.path, $tcb.manifest.schema, $tcb.manifest.verifier, "$package/guard-system.json")) {
        if ($null -eq (Get-ComponentFor $self)) { Fail "Trusted component manifest is not self-protecting: $self is not a component path" }
    }
    if ($tcb.manifest.path -ne $system.manifests.trustedComponents) { Fail 'trusted-components.json manifest.path must equal guard-system.json manifests.trustedComponents' }

    # Verdict chain: workflow entries and the package scripts they reference, without following package tests.
    $workflow = [IO.File]::ReadAllText((Join-Path $targetRepository $WorkflowPath))
    $entries = @([Regex]::Matches($workflow, '\./(docs/guards/[^\s''"]+\.ps1)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
    $scripts = @{}
    $scanRoots = @((Full $package), (Full 'docs/guards/V3/build'), (Full 'docs/guards/V3/tests')) | Where-Object { [IO.Directory]::Exists($_) }
    foreach ($file in @($scanRoots | ForEach-Object { Get-ChildItem -LiteralPath $_ -Recurse -File } | Where-Object { $_.Extension -in @('.ps1', '.psm1') })) {
        $relative = [IO.Path]::GetRelativePath($root, $file.FullName).Replace('\', '/')
        if ($relative -match '/(bin|obj)/') { continue }
        if (-not $scripts.ContainsKey($file.Name)) { $scripts[$file.Name] = [Collections.Generic.List[string]]::new() }
        $scripts[$file.Name].Add($relative)
    }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $queue = [Collections.Generic.Queue[string]]::new()
    foreach ($entry in $entries) { if ($seen.Add($entry)) { $queue.Enqueue($entry) } }
    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        if (-not (Exists $current)) { Fail "Workflow references a missing script: $current"; continue }
        if ($current -match '/tests/') { continue }
        $text = [IO.File]::ReadAllText((Full $current))
        foreach ($token in ([Regex]::Matches($text, '[A-Za-z0-9][A-Za-z0-9.-]*\.psm?1') | ForEach-Object { $_.Value } | Select-Object -Unique)) {
            if (-not $scripts.ContainsKey($token)) { continue }
            foreach ($candidate in $scripts[$token]) { if ($seen.Add($candidate)) { $queue.Enqueue($candidate) } }
        }
    }
    foreach ($path in $seen) {
        if ($null -eq (Get-ComponentFor $path)) { Fail "Verdict-chain script is outside the trusted component manifest: $path" }
    }
    $gateCommands = if ($null -ne $commands) { @($commands.commands) } else { @() }
    foreach ($command in @($gateCommands | Where-Object { $_.kind -ne 'maintenance' -and @($_.stages | Where-Object { $_ -in @('post', 'diff', 'ci') }).Count -gt 0 })) {
        if ($null -eq (Get-ComponentFor $command.entryPoint)) { Fail "Gate command '$($command.id)' entry point is outside the trusted component manifest: $($command.entryPoint)" }
    }
}

# ---------------------------------------------------------------- domain authority registry and gate trust inputs (Plan 06 D18)
# The registry is package configuration; the authority files it names are target data. Static checks only:
# every domain authority literal in package engine scripts is registered, every registered pointer role resolves,
# and every detector closure reads exactly the authorities its gate declares.
$domainRoots = '^(deployment/|docs/architecture/review/(gates|policies)/|src/DatabaseMigrator/IFX\.DatabaseMigrator/migration-manifest\.json$)'
$domainLiteral = '[''"]((?:deployment|docs/architecture/review/(?:gates|policies))/[^''"*$`]+?|src/DatabaseMigrator/IFX\.DatabaseMigrator/migration-manifest\.json)[''"]'
$packageDirectory = [IO.Path]::GetFullPath((Full $package))
function Get-DomainAuthorityLiterals([string] $text) {
    foreach ($match in [Regex]::Matches($text, $domainLiteral)) {
        $literal = $match.Groups[1].Value.TrimEnd('/')
        $extension = [IO.Path]::GetExtension($literal)
        # Directory literals and documentation are not authorities; reads composed at runtime are outside this static lint.
        if (-not $extension -or $extension -in @('.md', '.mmd', '.png', '.svg')) { continue }
        $literal
    }
}
function Measure-PointerMatches([object] $node, [string[]] $segments, [int] $index) {
    if ($index -ge $segments.Count) { return 1 }
    $segment = $segments[$index].Replace('~1', '/').Replace('~0', '~')
    $count = 0
    if ($node -is [Collections.IDictionary]) {
        $keys = if ($segment -eq '*') { @($node.Keys) } elseif ($node.Contains($segment)) { @($segment) } else { @() }
        foreach ($key in $keys) { $count += Measure-PointerMatches $node[$key] $segments ($index + 1) }
    }
    elseif ($node -is [Collections.IList] -and $node -isnot [string]) {
        $indexes = if ($segment -eq '*') { @(for ($i = 0; $i -lt $node.Count; $i++) { $i }) } elseif ($segment -match '^(0|[1-9][0-9]*)$' -and [int]$segment -lt $node.Count) { @([int]$segment) } else { @() }
        foreach ($item in $indexes) { $count += Measure-PointerMatches $node[$item] $segments ($index + 1) }
    }
    return $count
}

$authorityById = @{}
$authorityByPath = @{}
$registry = Read-Manifest "$package/policy/authorities.json" 'authorities'
if ($null -ne $registry) {
    foreach ($authority in $registry.domainAuthorities) {
        if ($authorityById.ContainsKey($authority.id)) { Fail "Duplicate domain authority id: $($authority.id)" }
        if ($authorityByPath.ContainsKey($authority.path)) { Fail "Duplicate domain authority path: $($authority.path)" }
        $authorityById[$authority.id] = $authority
        $authorityByPath[$authority.path] = $authority
        if ($authority.path -notmatch $domainRoots) { Fail "Domain authority '$($authority.id)' is outside the domain authority roots: $($authority.path)" }
        $authorityFile = Join-Path $targetRepository $authority.path
        if (-not [IO.File]::Exists($authorityFile)) { Fail "Domain authority '$($authority.id)' is missing in the target: $($authority.path)"; continue }
        if (-not $authority.ContainsKey('pointerRoles')) { continue }
        try { $authorityDocument = Get-Content -LiteralPath $authorityFile -Raw | ConvertFrom-Json -AsHashtable -Depth 100 }
        catch { Fail "Domain authority '$($authority.id)' is not JSON, so its pointer roles cannot resolve: $($authority.path)"; continue }
        $pointers = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($entry in $authority.pointerRoles) {
            if (-not $pointers.Add($entry.pointer)) { Fail "Domain authority '$($authority.id)' repeats pointer $($entry.pointer)"; continue }
            if ($entry.role -eq $authority.defaultRole) { Fail "Domain authority '$($authority.id)' pointer $($entry.pointer) repeats the default role" }
            $segments = @($entry.pointer.Split('/') | Select-Object -Skip 1)
            if ((Measure-PointerMatches $authorityDocument $segments 0) -eq 0) { Fail "Domain authority '$($authority.id)' pointer $($entry.pointer) matches nothing in $($authority.path)" }
        }
    }
    $projectionEntries = @(@($registry.projections) + @($registry.g04Bindings))
    foreach ($projection in $projectionEntries) {
        if (-not $authorityByPath.ContainsKey($projection.source)) { Fail "Policy projection source is not a registered domain authority: $($projection.source)" }
    }

    $engineScripts = @{}
    foreach ($file in @(Get-ChildItem -LiteralPath $packageDirectory -Recurse -File | Where-Object { $_.Extension -in @('.ps1', '.psm1') })) {
        $relative = [IO.Path]::GetRelativePath($packageDirectory, $file.FullName).Replace('\', '/')
        if ($relative -match '^(tests|analysis)/' -or $relative -match '(^|/)(bin|obj)/') { continue }
        $engineScripts[$relative] = [IO.File]::ReadAllText($file.FullName)
        foreach ($literal in (Get-DomainAuthorityLiterals $engineScripts[$relative])) {
            if (-not $authorityByPath.ContainsKey($literal)) { Fail "Engine script $relative reads an unregistered domain authority: $literal" }
        }
    }
    $scriptsByName = @{}
    foreach ($relative in $engineScripts.Keys) {
        $name = [IO.Path]::GetFileName($relative)
        if (-not $scriptsByName.ContainsKey($name)) { $scriptsByName[$name] = [Collections.Generic.List[string]]::new() }
        $scriptsByName[$name].Add($relative)
    }

    foreach ($stage in $stageDocs.Values) {
        foreach ($gate in @($stage.gates)) {
            $contract = $gate.trustContract
            $declared = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            $derivedPackageInputs = [Collections.Generic.List[string]]::new()
            foreach ($trustInput in @($contract.inputs)) {
                $kind, $value = $trustInput.ref.Split(':', 2)
                switch ($kind) {
                    'authority' {
                        if (-not $authorityById.ContainsKey($value)) { Fail "Gate '$($gate.id)' references an unknown domain authority: $value"; break }
                        [void]$declared.Add($value)
                        $expected = if ($authorityById[$value].defaultRole -eq 'derived-projection') { 'derived-candidate' } else { 'head-candidate' }
                        if ($trustInput.source -ne $expected) { Fail "Gate '$($gate.id)' input $($trustInput.ref) must come from $expected, not $($trustInput.source)" }
                    }
                    'package' {
                        $packagePath = Join-Path $packageDirectory $value
                        $present = if ($value.EndsWith('/')) { [IO.Directory]::Exists($packagePath) } else { [IO.File]::Exists($packagePath) }
                        if (-not $present) { Fail "Gate '$($gate.id)' input $($trustInput.ref) is missing from the package" }
                        if ($trustInput.source -notin @('base', 'derived-candidate')) { Fail "Gate '$($gate.id)' package input $($trustInput.ref) must come from base or derived-candidate" }
                        if ($trustInput.source -eq 'derived-candidate') { $derivedPackageInputs.Add($value) }
                    }
                    'target' {
                        if ($trustInput.source -ne 'head-target') { Fail "Gate '$($gate.id)' target input $($trustInput.ref) must come from head-target" }
                    }
                }
            }
            # A candidate projection is regenerated from its head authorities, so the gate must declare those sources too.
            foreach ($prefix in $derivedPackageInputs) {
                $covered = @($projectionEntries | Where-Object { $_.target -eq $prefix -or ($prefix.EndsWith('/') -and $_.target.StartsWith($prefix)) })
                if ($covered.Count -eq 0) { Fail "Gate '$($gate.id)' derived-candidate input package:$prefix is not a registered policy projection" }
                foreach ($projection in $covered) {
                    $source = $authorityByPath[$projection.source]
                    if ($null -ne $source -and -not $declared.Contains($source.id)) { Fail "Gate '$($gate.id)' consumes projection $($projection.target) without declaring its authority '$($source.id)'" }
                }
            }
            if (-not $contract.ContainsKey('detectors')) { continue }
            $closure = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            $pending = [Collections.Generic.Queue[string]]::new()
            foreach ($detector in $contract.detectors) {
                if (-not $engineScripts.ContainsKey($detector)) { Fail "Gate '$($gate.id)' detector is not a package engine script: $detector"; continue }
                if ($closure.Add($detector)) { $pending.Enqueue($detector) }
            }
            $read = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            while ($pending.Count -gt 0) {
                $current = $pending.Dequeue()
                foreach ($literal in (Get-DomainAuthorityLiterals $engineScripts[$current])) {
                    if ($authorityByPath.ContainsKey($literal)) { [void]$read.Add($authorityByPath[$literal].id) }
                }
                foreach ($token in ([Regex]::Matches($engineScripts[$current], '[A-Za-z0-9][A-Za-z0-9.-]*\.psm?1') | ForEach-Object { $_.Value } | Select-Object -Unique)) {
                    if (-not $scriptsByName.ContainsKey($token)) { continue }
                    foreach ($candidate in $scriptsByName[$token]) { if ($closure.Add($candidate)) { $pending.Enqueue($candidate) } }
                }
            }
            foreach ($id in $read) { if (-not $declared.Contains($id)) { Fail "Gate '$($gate.id)' detectors read domain authority '$id' without declaring it as an input" } }
            foreach ($id in $declared) {
                $viaProjection = @($derivedPackageInputs).Count -gt 0
                if (-not $read.Contains($id) -and -not $viaProjection) { Fail "Gate '$($gate.id)' declares domain authority '$id' that its detectors do not read" }
            }
        }
    }
}

# ---------------------------------------------------------------- compatibility entries
foreach ($entry in $system.compatibility.entries) {
    $legacy = $entry.legacyPath
    if (-not ([IO.File]::Exists((Full $legacy)) -or [IO.Directory]::Exists((Full $legacy)))) { Fail "Compatibility entry references a missing legacy path: $legacy" }
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Host "FAIL $failure" }
    Write-Host "Manifest check failed: $($failures.Count) problem(s)."
    exit 1
}
Write-Host "Manifest check passed: $($stageDocs.Count) stages, $($commandIds.Count) commands, $(@($tcb.components).Count) trusted components, $($required.Count) gates."
