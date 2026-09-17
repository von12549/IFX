[CmdletBinding()]
param(
    [string] $TargetRoot,
    [string] $WorkflowPath = '.github/workflows/v3-ifx-guardrails.yml',
    [string] $JobsPath,
    [string] $RulesetJsonPath,
    [switch] $Remote,
    [string] $Repository,
    [string] $ReportPath
)

# Read-only CI contract verifier (Plan 06 P1.3): workflow jobs <-> ci/jobs.json <-> GitHub ruleset.
# Local mode checks the workflow against ci/jobs.json. -RulesetJsonPath or -Remote adds the ruleset comparison;
# -Remote only issues GET requests through the GitHub CLI.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = if ($TargetRoot) { [IO.Path]::GetFullPath($TargetRoot) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..')) }
function Resolve-InRoot([string] $path) { if ([IO.Path]::IsPathRooted($path)) { return $path } return (Join-Path $root $path) }

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
$triggers = [Collections.Generic.List[string]]::new()
$pushBranches = @()
$jobs = [ordered]@{}
$section = $null; $current = $null; $inMatrix = $false; $inPush = $false
foreach ($line in $lines) {
    if ($line -match '^(on|jobs|permissions):\s*$') { $section = $Matches[1]; $current = $null; continue }
    if ($line -match '^\S') { $section = $null; continue }
    if ($section -eq 'on') {
        if ($line -match '^  ([a-z_]+):') { $triggers.Add($Matches[1]); $inPush = $Matches[1] -eq 'push'; continue }
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

# ---------------------------------------------------------------- ci/jobs.json
# ci/jobs.json is package configuration (read from this package by default); the workflow is read from the target repository.
$jobsFile = if ($JobsPath) { Resolve-InRoot $JobsPath } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'jobs.json')) }
if (-not [IO.File]::Exists($jobsFile)) { throw "CI job declaration is missing: $jobsFile" }
$declaration = Get-Content -LiteralPath $jobsFile -Raw | ConvertFrom-Json -AsHashtable
$declared = @($declaration.jobs)
$declaredIds = @($declared | ForEach-Object { [string]$_.id })
Add-Check 'declaration-workflow-path' ($declaration.automaticGuardWorkflow -eq $WorkflowPath.Replace('\', '/')) "jobs.json automaticGuardWorkflow is '$($declaration.automaticGuardWorkflow)'"
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
# When jobs.json declares trusted execution active, every required check must take its verdict from the runner in the
# base worktree with its own gate ID, and no job may take a verdict from the head dispatcher in place.
$trustedBase = if ($declaration.Contains('trustedBase')) { $declaration.trustedBase } else { $null }
if ($null -ne $trustedBase -and $trustedBase.execution -eq 'active') {
    foreach ($jobId in $jobs.Keys) {
        $job = $jobs[$jobId]
        $text = $job.lines -join "`n"
        $inPlace = @($job.lines | Where-Object { $_ -match '\./docs/guards/V3_ifx/scripts/Invoke-IFXGuardrails\.ps1' })
        Add-Check "trusted-base-no-head-dispatcher:$jobId" ($inPlace.Count -eq 0) 'jobs must not run the head dispatcher in place; use the trusted base runner'
        $gateIds = @([Regex]::Matches($text, '(?m)\$env:GUARD_BASE/docs/guards/V3_ifx/trusted-base/Invoke-IFXTrustedBase\.ps1"?\s.*?-GateId\s+(.+?)\s*$') | ForEach-Object { $_.Groups[1].Value })
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
    Add-Check 'ruleset-identity' ([string]$ruleset.id -eq [string]$declaration.ruleset.id -and $ruleset.name -eq $declaration.ruleset.name) "ruleset $($ruleset.id) '$($ruleset.name)' does not match jobs.json"
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
    status = $status; workflow = $WorkflowPath; declaration = $JobsPath
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
Write-Host "CI contract passed ($($report.mode)): $($checkNames.Count) checks match $JobsPath"
