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
$root = if ($TargetRoot) { [IO.Path]::GetFullPath($TargetRoot) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..')) }
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
    $workflow = [IO.File]::ReadAllText((Full $WorkflowPath))
    $entries = @([Regex]::Matches($workflow, '\./(docs/guards/[^\s''"]+\.ps1)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
    $scripts = @{}
    foreach ($file in (Get-ChildItem -LiteralPath (Full $package) -Recurse -File -Filter '*.ps1')) {
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
        foreach ($token in ([Regex]::Matches($text, '[A-Za-z0-9][A-Za-z0-9.-]*\.ps1') | ForEach-Object { $_.Value } | Select-Object -Unique)) {
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
