[CmdletBinding()]
param(
    [string] $TargetRoot,
    [string] $WorkflowPath = '.github/workflows/v3-ifx-guardrails.yml',
    [string] $RequiredChecksPath,
    [string] $RulesetJsonPath,
    [switch] $Remote,
    [string] $Repository,
    [string] $ReportPath
)

# Read-only CI contract verifier: workflow jobs <-> stages/ci/required-checks.json <-> GitHub ruleset.
# Local mode checks the workflow against required-checks.json. -RulesetJsonPath or -Remote adds the ruleset comparison;
# -Remote only issues GET requests through the GitHub CLI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = if ($TargetRoot) { [IO.Path]::GetFullPath($TargetRoot) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..')) }
function Resolve-InRoot([string] $path) { if ([IO.Path]::IsPathRooted($path)) { return $path } return (Join-Path $root $path) }
function Resolve-RequiredChecksSchema {
    $package = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $available = @(@('contracts/required-checks.schema.json', 'stages/ci/contracts/required-checks.schema.json') | ForEach-Object { Join-Path $package $_ } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    if ($available.Count -ne 1) { throw "Exactly one legacy or CI-owned required-checks schema must exist; found $($available.Count)." }
    return $available[0]
}

$failures = [Collections.Generic.List[string]]::new()
$checks = [Collections.Generic.List[object]]::new()
function Add-Check([string] $id, [bool] $passed, [string] $detail) {
    $checks.Add([ordered]@{ id = $id; status = if ($passed) { 'pass' } else { 'fail' }; detail = $detail })
    if (-not $passed) { $failures.Add("${id}: $detail") }
}
function Format-Set([string[]] $values) { return (@($values | Sort-Object -Unique) -join ', ') }

# ---------------------------------------------------------------- workflow (line-based; the workflow is hand-authored with 2-space indentation)
$workflowFile = Resolve-InRoot $WorkflowPath
if (-not [IO.File]::Exists($workflowFile)) { throw "Workflow is missing: $WorkflowPath" }
$lines = [IO.File]::ReadAllText($workflowFile).Replace("`r`n", "`n") -split "`n"
$yamlProblems = [Collections.Generic.List[string]]::new()
$topLevel = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($line in $lines) {
    if ($line.Contains("`t")) { $yamlProblems.Add('tab indentation is not allowed') }
    if ($line -match '^( +)\S' -and ($Matches[1].Length % 2) -ne 0) { $yamlProblems.Add("odd indentation: $line") }
    if ($line -match '^([A-Za-z][A-Za-z0-9_-]*):') {
        if (-not $topLevel.Add($Matches[1])) { $yamlProblems.Add("duplicate top-level key: $($Matches[1])") }
    }
}
foreach ($requiredTopLevel in @('name', 'on', 'permissions', 'jobs')) {
    if (-not $topLevel.Contains($requiredTopLevel)) { $yamlProblems.Add("missing top-level key: $requiredTopLevel") }
}
Add-Check 'workflow-yaml-canonical' ($yamlProblems.Count -eq 0) "canonical YAML structural parse problems [$(Format-Set @($yamlProblems))]"
$triggers = [Collections.Generic.List[string]]::new()
$pushBranches = @()
$jobs = [ordered]@{}
$section = $null; $current = $null; $inMatrix = $false; $inPush = $false
$schedule = [Collections.Generic.List[string]]::new()
$concurrency = [ordered]@{ group = $null; cancelInProgress = $false }
$inConcurrency = $false; $inSchedule = $false
foreach ($line in $lines) {
    if ($line -match '^(on|jobs|permissions):\s*$') { $section = $Matches[1]; $current = $null; $inConcurrency = $false; continue }
    if ($line -match '^concurrency:\s*$') { $section = $null; $current = $null; $inConcurrency = $true; continue }
    if ($line -match '^\S') { $section = $null; $inConcurrency = $false; continue }
    if ($inConcurrency) {
        if ($line -match '^  group:\s*(.+?)\s*$') { $concurrency.group = $Matches[1] }
        elseif ($line -match '^  cancel-in-progress:\s*(true|false)\s*$') { $concurrency.cancelInProgress = $Matches[1] -eq 'true' }
        continue
    }
    if ($section -eq 'on') {
        if ($line -match '^  ([a-z_]+):') { $triggers.Add($Matches[1]); $inPush = $Matches[1] -eq 'push'; $inSchedule = $Matches[1] -eq 'schedule'; continue }
        if ($inSchedule -and $line -match "^    - cron:\s*'(.+?)'\s*$") { $schedule.Add($Matches[1]); continue }
        if ($inPush -and $line -match '^    branches:\s*\[(.*)\]') { $pushBranches = @($Matches[1] -split ',' | ForEach-Object { $_.Trim().Trim("'", '"') }) }
        continue
    }
    if ($section -ne 'jobs') { continue }
    if ($line -match '^  ([A-Za-z0-9_-]+):\s*$') {
        $current = $Matches[1]; $inMatrix = $false
        $jobs[$current] = [ordered]@{ name = $null; condition = $null; needs = @(); matrix = [ordered]@{}; lines = [Collections.Generic.List[string]]::new() }
        continue
    }
    if ($null -eq $current) { continue }
    $jobs[$current].lines.Add($line)
    if ($line -match '^    name:\s*(.+?)\s*$') { $jobs[$current].name = $Matches[1]; continue }
    if ($line -match '^    if:\s*(.+?)\s*$') { $jobs[$current].condition = $Matches[1]; continue }
    if ($line -match '^    needs:\s*\[(.*)\]\s*$') { $jobs[$current].needs = @($Matches[1] -split ',' | ForEach-Object { $_.Trim() }); continue }
    if ($line -match '^    needs:\s*([A-Za-z0-9_-]+)\s*$') { $jobs[$current].needs = @($Matches[1]); continue }
    if ($line -match '^      matrix:\s*$') { $inMatrix = $true; continue }
    if ($inMatrix -and $line -match '^        ([A-Za-z0-9_-]+):\s*\[(.*)\]\s*$') {
        $jobs[$current].matrix[$Matches[1]] = @($Matches[2] -split ',' | ForEach-Object { $_.Trim().Trim("'", '"') }); continue
    }
    if ($line -match '^    \S' -and $line -notmatch '^    strategy:') { $inMatrix = $false }
}

$checkNames = [ordered]@{}
foreach ($jobId in $jobs.Keys) {
    $job = $jobs[$jobId]
    if ([string]::IsNullOrWhiteSpace($job.name)) { Add-Check "workflow-job-name:$jobId" $false 'job has no name; check names must be explicit'; continue }
    $names = @($job.name)
    foreach ($match in [Regex]::Matches($job.name, '\$\{\{\s*matrix\.([A-Za-z0-9_-]+)\s*\}\}')) {
        $key = $match.Groups[1].Value
        if (-not $job.matrix.Contains($key)) { Add-Check "workflow-matrix:$jobId" $false "matrix.$key is used in the name but not declared as an inline list"; $names = @(); break }
        $names = @(foreach ($name in $names) { foreach ($value in $job.matrix[$key]) { $name.Replace($match.Value, $value) } })
    }
    foreach ($name in $names) {
        if ($checkNames.Contains($name)) { Add-Check "workflow-unique-name:$name" $false "duplicate check name in jobs $($checkNames[$name]) and $jobId" }
        $checkNames[$name] = $jobId
    }
}
foreach ($jobId in $jobs.Keys) {
    foreach ($dependency in $jobs[$jobId].needs) {
        Add-Check "workflow-needs:$jobId->$dependency" ($jobs.Contains($dependency)) 'needs must reference a job in the same workflow'
    }
}
Add-Check 'workflow-triggers' (@(@('pull_request', 'push') | Where-Object { $_ -notin $triggers }).Count -eq 0 -and 'main' -in $pushBranches) "pull_request and push to main are required; found triggers [$(Format-Set $triggers)] push branches [$(Format-Set $pushBranches)]"

# Every repository PowerShell entry in the workflow must be a stable public command. Internal engines and tests remain
# reachable only behind those commands, so physical moves cannot silently change the CI integration surface (P9/P10).
$commandManifest = Get-Content -LiteralPath ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../shared/commands.json'))) -Raw | ConvertFrom-Json -AsHashtable -Depth 30
$publicEntries = @($commandManifest.commands | Where-Object { $_.kind -eq 'public' } | ForEach-Object { [string]$_.entryPoint })
$workflowEntries = @([Regex]::Matches(($lines -join "`n"), '(?m)-File\s+"?(?:\$env:GUARD_BASE/|\./)(docs/guards/[A-Za-z0-9_./-]+\.ps1)"?') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
$nonPublicEntries = @($workflowEntries | Where-Object { $_ -notin $publicEntries })
Add-Check 'workflow-public-commands' ($nonPublicEntries.Count -eq 0) "workflow script entries not declared public [$(Format-Set $nonPublicEntries)]"

# ---------------------------------------------------------------- stages/ci/required-checks.json
# The declaration is package authority by default; the workflow is read from the target repository.
$requiredChecksFile = if ($RequiredChecksPath) { Resolve-InRoot $RequiredChecksPath } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../stages/ci/required-checks.json')) }
if (-not [IO.File]::Exists($requiredChecksFile)) { throw "Required-check declaration is missing: $requiredChecksFile" }
$declaration = Get-Content -LiteralPath $requiredChecksFile -Raw | ConvertFrom-Json -AsHashtable
$requiredChecksSchema = Resolve-RequiredChecksSchema
if (-not (Test-Json -Path $requiredChecksFile -SchemaFile $requiredChecksSchema -ErrorAction Stop)) { throw "Required-check declaration does not match its schema: $requiredChecksFile" }
$declared = @($declaration.jobs)
$declaredIds = @($declared | ForEach-Object { [string]$_.id })
Add-Check 'declaration-workflow-path' ($declaration.automaticGuardWorkflow -eq '.github/workflows/v3-ifx-guardrails.yml') "required-checks.json automaticGuardWorkflow is '$($declaration.automaticGuardWorkflow)'"
Add-Check 'declaration-unique-ids' ((@($declaredIds | Select-Object -Unique)).Count -eq $declaredIds.Count) 'job IDs must be unique'
$missingInDeclaration = @($checkNames.Keys | Where-Object { $_ -notin $declaredIds })
$missingInWorkflow = @($declaredIds | Where-Object { -not $checkNames.Contains($_) })
Add-Check 'declaration-matches-workflow' ($missingInDeclaration.Count -eq 0 -and $missingInWorkflow.Count -eq 0) "workflow checks not declared [$(Format-Set $missingInDeclaration)]; declared jobs not in workflow [$(Format-Set $missingInWorkflow)]"
Add-Check 'declaration-required-count' ([int]$declaration.ruleset.requiredCheckCount -eq $declaredIds.Count) "ruleset.requiredCheckCount $($declaration.ruleset.requiredCheckCount) != declared jobs $($declaredIds.Count)"
foreach ($entry in $declared) {
    $id = [string]$entry.id
    Add-Check "declaration-blocking:$id" ($entry.blocking -eq $true) 'every declared job is a required, blocking check'
    if (-not $checkNames.Contains($id)) { continue }
    $condition = $jobs[$checkNames[$id]].condition
    switch ([string]$entry.trigger) {
        'pull-request' { Add-Check "declaration-trigger:$id" ($condition -match "^github\.event_name\s*==\s*'pull_request'$") "trigger pull-request requires job condition github.event_name == 'pull_request'; found '$condition'" }
        'pull-request-and-main' { Add-Check "declaration-trigger:$id" ([string]::IsNullOrEmpty($condition)) "trigger pull-request-and-main requires an unconditional job; found '$condition'" }
        default { Add-Check "declaration-trigger:$id" $false "unknown trigger '$($entry.trigger)'" }
    }
}

# ---------------------------------------------------------------- trusted base activation (Plan 06 §11.1)
# When required-checks.json declares trusted execution active, every required check must take its verdict from the runner in the
# base worktree with its own gate ID, and no job may take a verdict from the head dispatcher in place.
$trustedBase = if ($declaration.Contains('trustedBase')) { $declaration.trustedBase } else { $null }
if ($null -ne $trustedBase -and $trustedBase.execution -eq 'active') {
    foreach ($jobId in $jobs.Keys) {
        $job = $jobs[$jobId]
        $text = $job.lines -join "`n"
        $inPlace = @($job.lines | Where-Object { $_ -match '\./docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails\.ps1' })
        Add-Check "trusted-base-no-head-dispatcher:$jobId" ($inPlace.Count -eq 0) 'jobs must not run the head dispatcher in place; use the trusted base runner'
        $guardExecutables = @($job.lines | Where-Object { $_ -match '^\s+(pwsh\s+.*?-File\s+|\./)"?[^" ]*docs/guards/' })
        $firstExecutable = if ($guardExecutables.Count) { $guardExecutables[0].Trim() } else { '' }
        Add-Check "trusted-base-first-verdict:$jobId" ($firstExecutable -match '\$env:GUARD_BASE/docs/guards/') "the first guard executable must come from the base worktree; found '$firstExecutable'"
        $gateIds = @([Regex]::Matches($text, '(?m)\$env:GUARD_BASE/docs/guards/V3_ifx/commands/Invoke-IFXGuardrails\.ps1"?\s+-TrustedBase\s+.*?-GateId\s+(.+?)\s*$') | ForEach-Object { $_.Groups[1].Value })
        # Gate IDs may use the job's inline matrix, expanded the same way as check names.
        $resolved = @(foreach ($gateId in $gateIds) {
            $values = @($gateId)
            foreach ($match in [Regex]::Matches($gateId, '\$\{\{\s*matrix\.([A-Za-z0-9_-]+)\s*\}\}')) {
                $key = $match.Groups[1].Value
                if (-not $job.matrix.Contains($key)) { continue }
                $values = @(foreach ($value in $values) { foreach ($item in $job.matrix[$key]) { $value.Replace($match.Value, $item) } })
            }
            $values
        })
        foreach ($name in @($checkNames.Keys | Where-Object { $checkNames[$_] -eq $jobId })) {
            if ($name -notin $declaredIds) { continue }
            Add-Check "trusted-base-runner:$name" ($name -in $resolved) "check $name must run Invoke-IFXTrustedBase.ps1 from `$env:GUARD_BASE with -GateId $name; found [$(Format-Set $resolved)]"
        }
        Add-Check "trusted-base-worktree:$jobId" ($text -match 'git worktree add --detach "\$env:RUNNER_TEMP/guard-base"') 'jobs must create the base worktree outside the checkout in $RUNNER_TEMP/guard-base'
    }
}

# ---------------------------------------------------------------- cost controls and verified change scope (Plan 06 D28)
# Cost controls may only make a run cheaper without changing what a gate proves: superseded runs are cancelled, reviewed
# packages are cached, and gate work is inherited from the base only for the scope the base itself classifies.
$costControls = if ($declaration.Contains('costControls')) { $declaration.costControls } else { $null }
if ($null -ne $costControls) {
    Add-Check 'cost-concurrency' ($concurrency.group -eq [string]$costControls.concurrencyGroup -and $concurrency.cancelInProgress -eq [bool]$costControls.cancelSupersededRuns -and [bool]$costControls.cancelSupersededRuns) "workflow concurrency group '$($concurrency.group)' cancel-in-progress $($concurrency.cancelInProgress) must match required-checks.json"
    Add-Check 'cost-schedule' (@($schedule) -contains [string]$costControls.scheduleCron) "workflow schedule [$(Format-Set @($schedule))] must contain the declared cron '$($costControls.scheduleCron)'"
    $cache = $costControls.packageCache
    foreach ($jobId in @($cache.jobs)) {
        $job = if ($jobs.Contains($jobId)) { $jobs[$jobId] } else { $null }
        if ($null -eq $job) { Add-Check "cost-package-cache:$jobId" $false 'declared cache job is not in the workflow'; continue }
        $text = $job.lines -join "`n"
        $hasAction = $text -match [Regex]::Escape([string]$cache.action)
        $hasPath = $text -match [Regex]::Escape([string]$cache.path)
        $hasKey = $text -match "key:\s*$([Regex]::Escape([string]$cache.keyPrefix))" -and $text -match [Regex]::Escape([string]$cache.lockGlob)
        Add-Check "cost-package-cache:$jobId" ($hasAction -and $hasPath -and $hasKey) "job must cache $($cache.path) with $($cache.action) and a key derived from $($cache.lockGlob)"
    }
}
$changeScope = if ($declaration.Contains('changeScope')) { $declaration.changeScope } else { $null }
if ($null -ne $changeScope) {
    # Classification runs through the base runner, so the workflow references no script that an older base lacks; both the
    # entry point and the implementation are this package's own files.
    $packagePrefix = 'docs/guards/V3_ifx/'
    $scopeEntryPoint = [string]$changeScope.entryPoint
    $scopeImplementation = [string]$changeScope.implementation
    $inPackage = {
        param([string] $relative)
        return $relative.StartsWith($packagePrefix, [StringComparison]::Ordinal) -and
            [IO.File]::Exists((Join-Path ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))) $relative.Substring($packagePrefix.Length)))
    }
    Add-Check 'change-scope-entry-point' ((& $inPackage $scopeEntryPoint) -and (& $inPackage $scopeImplementation)) "the declared classification entry point and implementation must be this package's own files: $scopeEntryPoint, $scopeImplementation"
    foreach ($jobId in @($changeScope.candidateStepJobs)) {
        $job = if ($jobs.Contains($jobId)) { $jobs[$jobId] } else { $null }
        if ($null -eq $job) { Add-Check "change-scope-step:$jobId" $false 'declared change scope job is not in the workflow'; continue }
        $text = $job.lines -join "`n"
        # The classification step is read on its own, so a reference anywhere else in the job cannot satisfy it.
        $current = [Collections.Generic.List[string]]::new()
        $stepLines = $null
        foreach ($line in $job.lines) {
            if ($line -match '^      - ') {
                if ($null -ne $stepLines) { break }
                $current = [Collections.Generic.List[string]]::new()
            }
            $current.Add($line)
            if ($line -match '^        id:\s*scope\s*$') { $stepLines = $current }
        }
        $step = if ($null -ne $stepLines) { $stepLines -join "`n" } else { '' }
        $classifies = $step -ne '' -and
            $step -match "\`$env:GUARD_BASE/$([Regex]::Escape($scopeEntryPoint))" -and
            $step -match '-TrustedBase\b' -and
            $step -match "-Mode\s+$([Regex]::Escape([string]$changeScope.mode))\b"
        $failsOpen = $step -match '(?m)^        continue-on-error:\s*true\s*$'
        $guards = @([Regex]::Matches($text, "(?m)^\s+if:\s*steps\.scope\.outputs\.scope\s*!=\s*'$([Regex]::Escape([string]$changeScope.inheritScope))'\s*$"))
        Add-Check "change-scope-step:$jobId" $classifies "job must classify the changed set with $scopeEntryPoint -Mode $($changeScope.mode) from `$env:GUARD_BASE in a step with id scope"
        Add-Check "change-scope-fails-open:$jobId" $failsOpen 'the classification step must be continue-on-error, so a base that cannot classify leads to a full run'
        Add-Check "change-scope-guard:$jobId" ($guards.Count -ge 1) "job must skip its head candidate work when the base classifies the changed set as $($changeScope.inheritScope)"
    }
    $undeclared = @(@($changeScope.inheritingChecks) | Where-Object { $_ -notin $declaredIds })
    Add-Check 'change-scope-inheriting-checks' ($undeclared.Count -eq 0) "checks that may inherit a base verdict must be declared jobs; found [$(Format-Set $undeclared)]"
}

# ---------------------------------------------------------------- ruleset (optional)
$ruleset = $null
if ($Remote) {
    $repo = $Repository
    if (-not $repo) {
        $url = (& git -C $root remote get-url origin).Trim()
        if ($url -match 'github\.com[:/]([^/]+/[^/.]+?)(\.git)?$') { $repo = $Matches[1] } else { throw "Cannot derive GitHub repository from origin: $url" }
    }
    $json = & gh api "repos/$repo/rulesets/$($declaration.ruleset.id)"
    if ($LASTEXITCODE -ne 0) { throw "Reading ruleset $($declaration.ruleset.id) failed." }
    $ruleset = ($json -join "`n") | ConvertFrom-Json -AsHashtable
} elseif ($RulesetJsonPath) {
    $ruleset = Get-Content -LiteralPath (Resolve-InRoot $RulesetJsonPath) -Raw | ConvertFrom-Json -AsHashtable
}
if ($null -ne $ruleset) {
    Add-Check 'ruleset-identity' ([string]$ruleset.id -eq [string]$declaration.ruleset.id -and $ruleset.name -eq $declaration.ruleset.name) "ruleset $($ruleset.id) '$($ruleset.name)' does not match required-checks.json"
    Add-Check 'ruleset-active' ($ruleset.enforcement -eq 'active') "enforcement is '$($ruleset.enforcement)'"
    $statusRule = @($ruleset.rules | Where-Object { $_.type -eq 'required_status_checks' })
    if ($statusRule.Count -ne 1) {
        Add-Check 'ruleset-required-status-checks' $false 'ruleset has no single required_status_checks rule'
    } else {
        $parameters = $statusRule[0].parameters
        Add-Check 'ruleset-strict' ([bool]$parameters.strict_required_status_checks_policy -eq [bool]$declaration.ruleset.strict -and [bool]$declaration.ruleset.strict) "strict is $($parameters.strict_required_status_checks_policy); strict up-to-date checks are required (Plan 06 §12.3)"
        $contexts = @($parameters.required_status_checks | ForEach-Object { [string]$_.context })
        $extra = @($contexts | Where-Object { $_ -notin $declaredIds }); $missing = @($declaredIds | Where-Object { $_ -notin $contexts })
        Add-Check 'ruleset-contexts' ($extra.Count -eq 0 -and $missing.Count -eq 0) "contexts not declared [$(Format-Set $extra)]; declared jobs not required [$(Format-Set $missing)]"
    }
}

$status = if ($failures.Count -eq 0) { 'pass' } else { 'fail' }
$report = [ordered]@{
    formatVersion = 1; mode = if ($Remote) { 'remote' } elseif ($RulesetJsonPath) { 'ruleset-file' } else { 'local' }
    status = $status; workflow = $WorkflowPath; declaration = if ($RequiredChecksPath) { $RequiredChecksPath } else { 'docs/guards/V3_ifx/stages/ci/required-checks.json' }
    checkNames = @($checkNames.Keys); checks = @($checks)
}
if ($ReportPath) {
    $reportFile = Resolve-InRoot $ReportPath
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($reportFile))
    [IO.File]::WriteAllText($reportFile, (($report | ConvertTo-Json -Depth 10).Replace("`r`n", "`n") + "`n"), [Text.UTF8Encoding]::new($false))
}
if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Host "FAIL $failure" }
    Write-Host "CI contract failed: $($failures.Count) problem(s)."
    exit 1
}
Write-Host "CI contract passed ($($report.mode)): $($checkNames.Count) checks match required-checks.json"
