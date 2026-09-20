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
function Resolve-AuthorityRegistryRelativePath {
    $available = @(@("$package/policy/authorities.json", "$package/shared/authorities/authorities.json") | Where-Object { [IO.File]::Exists((Full $_)) })
    if ($available.Count -ne 1) { Fail "Exactly one legacy or shared authority registry must exist; found $($available.Count)."; return $null }
    return $available[0]
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
$usesCommandLayout = $system.manifests.ContainsKey('docsMap')
$docsMap = if ($usesCommandLayout) { Read-Manifest $system.manifests.docsMap 'docs-map' } else { $null }

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
    $canonicalV3Entries = [ordered]@{
        'v3-runner' = if ($usesCommandLayout) { 'docs/guards/V3/commands/Invoke-V3.ps1' } else { 'docs/guards/V3/scripts/Invoke-V3.ps1' }
        'v3-setup' = if ($usesCommandLayout) { 'docs/guards/V3/commands/Invoke-V3Setup.ps1' } else { 'docs/guards/V3/scripts/Invoke-V3Setup.ps1' }
        'v3-architecture-review' = 'docs/guards/V3/scripts/Invoke-V3Architecture.ps1'
        'v3-docs' = if ($usesCommandLayout) { 'docs/guards/V3/commands/Invoke-V3Docs.ps1' } else { 'docs/guards/V3/scripts/Invoke-V3Docs.ps1' }
    }
    foreach ($id in $canonicalV3Entries.Keys) {
        $entry = @($commands.commands | Where-Object { $_.id -eq $id })
        if ($entry.Count -ne 1 -or $entry[0].entryPoint -cne $canonicalV3Entries[$id]) {
            Fail "Command '$id' must reference the canonical V3 entry point: $($canonicalV3Entries[$id])"
        }
    }
    $orchestratorPath = Full $(if ($usesCommandLayout) { "$package/commands/Invoke-IFXGuardrails.ps1" } else { "$package/scripts/Invoke-IFXGuardrails.ps1" })
    if ([IO.File]::Exists($orchestratorPath)) {
        $orchestrator = [IO.File]::ReadAllText($orchestratorPath)
        if (-not $orchestrator.Contains("'-ProtectionPath'", [StringComparison]::Ordinal) -or
            -not $orchestrator.Contains("'stages/diff/protection.json'", [StringComparison]::Ordinal)) {
            Fail 'IFX Diff must pass the overlay protection configuration to canonical V3.'
        }
    }
}

# The bridge accepts no alternate docs surface: docsMap is optional only until the commands/docs lifecycle candidate lands.
if ($null -ne $docsMap) {
    $documentIds = @($docsMap.documents | ForEach-Object { $_.id })
    $documentOutputs = @($docsMap.documents | ForEach-Object { $_.output })
    if (@($documentIds | Select-Object -Unique).Count -ne $documentIds.Count) { Fail 'docs-map document IDs must be unique.' }
    if (@($documentOutputs | Select-Object -Unique).Count -ne $documentOutputs.Count) { Fail 'docs-map output paths must be unique.' }
    foreach ($document in $docsMap.documents) {
        foreach ($source in $document.sources) {
            if (([string]$source.path).IndexOfAny([char[]]'*?[') -lt 0 -and -not (Exists $source.path)) { Fail "Docs source is missing for '$($document.id)': $($source.path)" }
        }
    }
}
foreach ($stage in $stageDocs.Values) {
    if ($null -ne $commands) { foreach ($id in $stage.commands) { if ($id -notin $commandIds) { Fail "Stage '$($stage.id)' references unknown command '$id'" } } }
    foreach ($dependency in $stage.dependencies) { if (-not $stageDocs.Contains($dependency)) { Fail "Stage '$($stage.id)' depends on unknown stage '$dependency'" } }
    foreach ($document in $stage.documentation) { if (-not (Exists $document)) { Fail "Stage '$($stage.id)' documentation is missing: $document" } }
}

# ---------------------------------------------------------------- one gate per required check
$jobs = Read-Manifest "$package/stages/ci/required-checks.json" 'required-checks'
$required = @($jobs.jobs | ForEach-Object { [string]$_.id })
$gateIds = @($stageDocs.Values | ForEach-Object { @($_.gates) } | ForEach-Object { [string]$_.id })
foreach ($id in $required) {
    $count = @($gateIds | Where-Object { $_ -eq $id }).Count
    if ($count -ne 1) { Fail "Required check '$id' must be declared by exactly one stage gate (found $count)" }
}
foreach ($id in ($gateIds | Select-Object -Unique)) { if ($id -notin $required) { Fail "Stage gate '$id' is not a required check in stages/ci/required-checks.json" } }

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
    # Entries run from the checkout (./docs/guards/...) or from the trusted base worktree ($env:GUARD_BASE/docs/guards/...).
    $entries = @([Regex]::Matches($workflow, '(?:\./|\$env:GUARD_BASE/)(docs/guards/[^\s''"]+\.ps1)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
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
        $explicitReferences = @([Regex]::Matches($text, 'docs/guards/[A-Za-z0-9_./-]+\.psm?1') | ForEach-Object { $_.Value } | Select-Object -Unique)
        foreach ($reference in $explicitReferences) {
            if ((Exists $reference) -and $seen.Add($reference)) { $queue.Enqueue($reference) }
        }
        foreach ($token in ([Regex]::Matches($text, '[A-Za-z0-9][A-Za-z0-9.-]*\.psm?1') | ForEach-Object { $_.Value } | Select-Object -Unique)) {
            if (-not $scripts.ContainsKey($token)) { continue }
            $candidates = [string[]]@($scripts[$token])
            $explicitMatches = [string[]]@($explicitReferences | Where-Object { $_.EndsWith("/$token", [StringComparison]::Ordinal) -or $_ -ceq $token })
            if ($explicitMatches.Count -gt 0) { continue }
            $local = [IO.Path]::GetRelativePath($root, [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetDirectoryName((Full $current))) $token))).Replace('\', '/')
            if ($candidates -ccontains $local) {
                if ($seen.Add($local)) { $queue.Enqueue($local) }
                continue
            }
            if ($candidates.Count -eq 1) {
                if ($seen.Add($candidates[0])) { $queue.Enqueue($candidates[0]) }
                continue
            }
            Fail "Ambiguous script reference '$token' from $current; use an explicit repository-relative path."
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

$authorityRegistryRelative = Resolve-AuthorityRegistryRelativePath
$authorityById = @{}
$authorityByPath = @{}
$registry = if ($authorityRegistryRelative) { Read-Manifest $authorityRegistryRelative 'authorities' } else { $null }
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
            # Candidate comparison matches wildcard array elements by a declared identity key, not by position.
            for ($i = 0; $i -lt $segments.Count; $i++) {
                if ($segments[$i] -ne '*') { continue }
                $arrayPointer = '/' + (@($segments | Select-Object -First $i) -join '/')
                if (@($(if ($authority.ContainsKey('arrayKeys')) { $authority.arrayKeys } else { @() }) | Where-Object { $_.pointer -eq $arrayPointer }).Count -eq 0) {
                    Fail "Domain authority '$($authority.id)' pointer $($entry.pointer) needs an arrayKeys entry for $arrayPointer"
                }
            }
        }
        foreach ($arrayKey in @($(if ($authority.ContainsKey('arrayKeys')) { $authority.arrayKeys } else { @() }))) {
            $node = $authorityDocument
            foreach ($segment in @($arrayKey.pointer.Split('/') | Select-Object -Skip 1)) {
                $node = if ($node -is [Collections.IDictionary] -and $node.Contains($segment)) { , $node[$segment] } else { $null }
            }
            $valid = $node -is [Collections.IList] -and $node -isnot [string]
            if ($valid) {
                $identities = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
                foreach ($item in $node) {
                    if ($item -isnot [Collections.IDictionary] -or -not $item.Contains($arrayKey.key) -or $item[$arrayKey.key] -isnot [string] -or -not $identities.Add($item[$arrayKey.key])) { $valid = $false; break }
                }
            }
            if (-not $valid) { Fail "Domain authority '$($authority.id)' arrayKeys $($arrayKey.pointer) is not an array of objects with a unique string '$($arrayKey.key)'" }
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

# ---------------------------------------------------------------- Diff protection (Plan 06 P3.2)
$protectionRelative = "$package/stages/diff/protection.json"
if (-not [IO.File]::Exists((Full $protectionRelative))) { Fail "Diff protection configuration is missing: $protectionRelative" }
else {
    try {
        if (-not (Test-Json -Path (Full $protectionRelative) -SchemaFile (Full "$package/contracts/protection.schema.json") -ErrorAction Stop)) { Fail "Schema validation failed: $protectionRelative" }
    } catch { Fail "Schema validation failed: ${protectionRelative}: $($_.Exception.Message)" }
}
# ---------------------------------------------------------------- policy and configuration registry (Plan 06 §12.4, D24)
Import-Module (Join-Path $root "$package/trusted-base/TrustedBase.psm1") -Force
$policyRegistry = Read-Manifest "$package/shared/policy-config.json" 'policy-config'
if ($null -ne $policyRegistry) {
    $authorityRegistry = if ($authorityRegistryRelative) { Get-Content -LiteralPath (Full $authorityRegistryRelative) -Raw | ConvertFrom-Json -AsHashtable -Depth 100 } else { $null }
    $projectionTargets = if ($null -ne $authorityRegistry) { Get-GuardProjectionTargets $authorityRegistry $package } else { [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal) }
    $entryIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($entry in @($policyRegistry.entries)) {
        if (-not $entryIds.Add([string]$entry.id)) { Fail "Duplicate policy registry entry id: $($entry.id)" }
        if ($entry.ContainsKey('schema') -and -not (Exists $entry.schema)) { Fail "Policy registry entry '$($entry.id)' names a missing schema: $($entry.schema)" }
        if ($entry.format -eq 'normalized-text' -and $entry.candidateValidation -ne 'normalized-text') { Fail "Policy registry entry '$($entry.id)' is normalized text but validated as $($entry.candidateValidation)" }
        foreach ($path in @($(if ($entry.ContainsKey('paths')) { $entry.paths } else { @() }))) {
            if ($projectionTargets.Contains($path)) { Fail "Policy registry entry '$($entry.id)' claims derived projection target $path" }
            if (@($policyRegistry.excluded | Where-Object { $path.StartsWith([string]$_, [StringComparison]::Ordinal) }).Count -gt 0) { Fail "Policy registry entry '$($entry.id)' claims excluded path $path" }
            # Paths outside the package, such as the root .gitattributes, belong to the target repository.
            if ($path.StartsWith("$package/", [StringComparison]::Ordinal) -and -not (Exists $path)) { Fail "Policy registry entry '$($entry.id)' names a missing file: $path" }
        }
    }
    foreach ($registryRoot in @($policyRegistry.roots)) {
        if (-not [IO.Directory]::Exists((Full $registryRoot))) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath (Full $registryRoot) -Recurse -File -Filter '*.json')) {
            $relative = [IO.Path]::GetRelativePath($root, $file.FullName).Replace('\', '/')
            if (-not (Test-GuardPolicyScope $policyRegistry $relative) -or $projectionTargets.Contains($relative)) { continue }
            if ($null -eq (Get-GuardPolicyEntry $policyRegistry $relative)) { Fail "Policy or configuration file is not registered in shared/policy-config.json: $relative" }
        }
    }
    $readSchema = { param($schema) if (Exists $schema) { [IO.File]::ReadAllText((Full $schema)) } else { $null } }
    foreach ($problem in (Test-GuardMonotonicityDeclarations $policyRegistry $readSchema)) { Fail $problem }
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
