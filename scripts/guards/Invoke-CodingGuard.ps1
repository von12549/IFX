[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Pre', 'Post', 'Diff')][string] $Stage,
    [ValidateSet('Focused', 'Full')][string] $Scope = 'Focused',
    [string[]] $PlannedPaths = @(),
    [string[]] $DeclaredPaths = @(),
    [string] $BaseRef,
    [string] $HeadRef,
    [string[]] $DecisionPath = @(),
    [string] $OutputPath,
    [string] $RepositoryRoot,
    [string] $Profile = 'ifx',
    [ValidateRange(1, 7200)][int] $TimeoutSeconds = 1800,
    [switch] $SkipCommands
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'GuardCore.psm1') -Force

function Get-ChangedEntries {
    param([string] $Root, [string] $Base, [string] $Head)
    $original = Get-Location
    try {
        Set-Location -LiteralPath $Root
        if ($Base) {
            & git rev-parse --verify "$Base^{commit}" *> $null
            if ($LASTEXITCODE -ne 0) { throw "Invalid base ref: $Base" }
            if ($Head) {
                & git rev-parse --verify "$Head^{commit}" *> $null
                if ($LASTEXITCODE -ne 0) { throw "Invalid head ref: $Head" }
                $range = "$Base...$Head"
            }
            else {
                $mergeBase = (& git merge-base $Base HEAD).Trim()
                if ($LASTEXITCODE -ne 0 -or -not $mergeBase) { throw "Cannot find merge-base for $Base" }
                $range = $mergeBase
            }
        }
        else {
            $range = 'HEAD'
        }
        $lines = @(& git diff --name-status --find-renames $range --)
        if ($LASTEXITCODE -ne 0) { throw 'git diff failed.' }
        $entries = [Collections.Generic.List[object]]::new()
        foreach ($line in $lines) {
            if (-not $line) { continue }
            $parts = $line -split "`t"
            $kind = $parts[0].Substring(0, 1)
            if ($kind -eq 'R' -or $kind -eq 'C') {
                if ($parts.Count -ne 3) { throw "Cannot parse git rename: $line" }
                $entries.Add([ordered]@{ status = $kind; path = $parts[2].Replace('\', '/'); previousPath = $parts[1].Replace('\', '/') })
            }
            else {
                if ($parts.Count -ne 2) { throw "Cannot parse git diff: $line" }
                $entries.Add([ordered]@{ status = $kind; path = $parts[1].Replace('\', '/') })
            }
        }
        if (-not $Head) {
            $untracked = @(& git ls-files --others --exclude-standard)
            if ($LASTEXITCODE -ne 0) { throw 'git ls-files failed.' }
            foreach ($path in $untracked) {
                if ($path) { $entries.Add([ordered]@{ status = 'A'; path = $path.Replace('\', '/') }) }
            }
        }
        return @($entries | Sort-Object { $_.path }, { $_.status })
    }
    finally { Set-Location $original }
}

function Get-Affected {
    param([object[]] $Entries, [object] $Manifest)
    $Entries = @($Entries | Where-Object { $null -ne $_ })
    $paths = @($Entries | ForEach-Object {
        $_.path
        if ($_.Contains('previousPath')) { $_.previousPath }
    } | Sort-Object -Unique)
    $areas = @($Manifest.areas | Where-Object {
        $area = $_
        @($paths | Where-Object { Test-GuardGlob $_ $area.pathPattern }).Count -gt 0
    })
    $risks = @($Manifest.riskTriggers | Where-Object {
        $risk = $_
        @($paths | Where-Object { Test-GuardGlob $_ $risk.pathPattern }).Count -gt 0
    })
    $rules = @($Manifest.rules | Where-Object {
        $rule = $_
        @($rule.scopePatterns | Where-Object {
            $pattern = $_
            @($paths | Where-Object { Test-GuardGlob $_ $pattern }).Count -gt 0
        }).Count -gt 0
    } | ForEach-Object { $_.id } | Sort-Object -Unique)
    return [ordered]@{ paths = $paths; areas = $areas; risks = $risks; rules = $rules }
}

function Get-Owner {
    param([string] $Source, [string] $Root, [string] $Path)
    if ($Source -like 'g03:*') {
        $file = Resolve-GuardPath $Root 'docs/architecture/review/gates/G03/generated/layerguard-governance-input.json' -MustExist
        $ownerData = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json -Depth 100
        $module = $Source.Substring(4)
        $row = @($ownerData.moduleOwnership | Where-Object { $_.module -eq $module })
        if ($row.Count -ne 1) { throw "G03 owner not found: $module" }
        return "$($row[0].owner) (backup: $($row[0].backupOwner))"
    }
    if ($Source -eq 'codeowners') {
        $file = Resolve-GuardPath $Root '.github/CODEOWNERS' -MustExist
        $owner = 'unassigned'
        foreach ($line in [IO.File]::ReadAllLines($file)) {
            $parts = @($line.Trim() -split '\s+' | Where-Object { $_ })
            if ($parts.Count -ge 2 -and -not $parts[0].StartsWith('#')) {
                $pattern = $parts[0].TrimStart('/')
                if ($pattern.EndsWith('/')) { $pattern += '**' }
                if (Test-GuardGlob $Path $pattern) { $owner = ($parts[1..($parts.Count - 1)] -join ' ') }
            }
        }
        return $owner
    }
    return $Source
}

function Test-DecisionCoverage {
    param([string] $Root, [string[]] $Paths, [object[]] $Risks, [string[]] $ChangedPaths)
    if ($Paths.Count -eq 0) { return [ordered]@{ valid = $false; reason = 'A decision record is required for high-risk paths.' } }
    $decisions = @($Paths | ForEach-Object {
        $normalized = $_.Replace('\', '/')
        if (-not (Test-GuardGlob $normalized 'docs/guards/decisions/*.json')) {
            throw 'Decision record must be in docs/guards/decisions/*.json.'
        }
        $document = Read-GuardDocument $Root $normalized 'docs/guards/contracts/decision.schema.json'
        foreach ($pattern in $document.affectedPaths) {
            Assert-GuardPattern ([string] $pattern)
            if ($pattern -eq '**') { throw 'Decision affectedPaths cannot cover the entire repository.' }
        }
        if ($document.ContainsKey('adrPath')) { [void] (Resolve-GuardPath $Root ([string] $document.adrPath) -MustExist) }
        [ordered]@{ path = $normalized; document = $document }
    })
    foreach ($risk in $Risks) {
        $riskPaths = @($ChangedPaths | Where-Object { Test-GuardGlob $_ $risk.pathPattern })
        foreach ($riskPath in $riskPaths) {
            if (@($decisions | Where-Object {
                $decision = $_
                @($decision.document.affectedPaths | Where-Object { Test-GuardGlob $riskPath $_ }).Count -gt 0
            }).Count -eq 0) {
                return [ordered]@{ valid = $false; reason = "No decision covers $riskPath ($($risk.id))." }
            }
        }
    }
    return [ordered]@{ valid = $true; reason = "Decision records $($Paths -join ', ') cover the triggered paths." }
}

function Invoke-GuardCommand {
    param([object] $Command, [string] $Root, [string] $StageName, [int] $Timeout)
    $directory = Resolve-GuardPath $Root ([string] $Command.workingDirectory) -MustExist
    $logDirectory = Resolve-GuardPath $Root 'artifacts/guards/logs'
    [void] [IO.Directory]::CreateDirectory($logDirectory)
    $stdout = Join-Path $logDirectory "$StageName-$($Command.id).stdout.log"
    $stderr = Join-Path $logDirectory "$StageName-$($Command.id).stderr.log"
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = [string] $Command.executable
    $start.WorkingDirectory = $directory
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Command.arguments) { [void] $start.ArgumentList.Add([string] $argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $startedAt = [DateTime]::UtcNow
    try {
        [void] $process.Start()
        $outTask = $process.StandardOutput.ReadToEndAsync()
        $errTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($Timeout * 1000)) {
            $process.Kill($true)
            [IO.File]::WriteAllText($stdout, $outTask.GetAwaiter().GetResult())
            [IO.File]::WriteAllText($stderr, $errTask.GetAwaiter().GetResult())
            return [ordered]@{ id = $Command.id; status = 'blocked'; exitCode = -1; reason = "Timed out after $Timeout seconds"; evidencePaths = @("artifacts/guards/logs/$StageName-$($Command.id).stdout.log", "artifacts/guards/logs/$StageName-$($Command.id).stderr.log") }
        }
        [IO.File]::WriteAllText($stdout, $outTask.GetAwaiter().GetResult())
        [IO.File]::WriteAllText($stderr, $errTask.GetAwaiter().GetResult())
        $status = if ($process.ExitCode -eq 0) { 'pass' } else { 'fail' }
        $reason = if ($status -eq 'pass') { 'Command completed.' } else { "Command exited $($process.ExitCode)." }
        $evidence = @("artifacts/guards/logs/$StageName-$($Command.id).stdout.log", "artifacts/guards/logs/$StageName-$($Command.id).stderr.log")
        if ($status -eq 'pass' -and $Command.Contains('expectedOutput')) {
            $relativeOutput = [string] $Command.expectedOutput
            $expectedPath = Resolve-GuardPath $Root $relativeOutput
            $fresh = if ([IO.File]::Exists($expectedPath)) {
                ([IO.FileInfo] $expectedPath).Length -gt 0 -and ([IO.FileInfo] $expectedPath).LastWriteTimeUtc -ge $startedAt
            }
            elseif ([IO.Directory]::Exists($expectedPath)) {
                @([IO.Directory]::EnumerateFiles($expectedPath, '*', [IO.SearchOption]::AllDirectories) | Where-Object { ([IO.FileInfo] $_).Length -gt 0 -and ([IO.FileInfo] $_).LastWriteTimeUtc -ge $startedAt }).Count -gt 0
            }
            else { $false }
            if ($fresh) { $evidence += $relativeOutput } else { $status = 'blocked'; $reason = "Expected fresh output is missing or empty: $relativeOutput" }
        }
        return [ordered]@{ id = $Command.id; status = $status; exitCode = $process.ExitCode; reason = $reason; evidencePaths = $evidence }
    }
    catch {
        return [ordered]@{ id = $Command.id; status = 'blocked'; exitCode = -1; reason = $_.Exception.Message; evidencePaths = @() }
    }
    finally { $process.Dispose() }
}

$root = Get-GuardRoot $RepositoryRoot
$stageName = $Stage.ToLowerInvariant()
if (-not $OutputPath) { $OutputPath = "artifacts/guards/$stageName-result.json" }
if (-not (Test-GuardGlob ($OutputPath.Replace('\', '/')) 'artifacts/guards/**')) { throw 'Guard result must be under artifacts/guards/.' }
$reportPath = Resolve-GuardPath $root $OutputPath
$report = [ordered]@{
    formatVersion = 1; gateId = "coding-guard-$stageName"; stage = $stageName
    status = 'blocked'; scope = $Scope.ToLowerInvariant(); ruleIds = @()
    inputHash = ''; checks = @(); evidencePaths = @(); reason = ''
}
try {
    if ($HeadRef -and -not $BaseRef) { throw 'Diff -HeadRef requires -BaseRef.' }
    $expected = New-GuardArtifacts $root $Profile
    $manifestPath = Resolve-GuardPath $root 'docs/guards/generated/guard-manifest.json' -MustExist
    foreach ($name in @('INDEX.md', 'COVERAGE_MATRIX.md', 'guard-manifest.json')) {
        $generatedPath = Resolve-GuardPath $root "docs/guards/generated/$name" -MustExist
        if ([IO.File]::ReadAllText($generatedPath) -cne [string] $expected[$name]) {
            throw "Generated guard artifact is stale: $name"
        }
    }
    $manifest = Read-GuardDocument $root 'docs/guards/generated/guard-manifest.json' 'docs/guards/contracts/guard-manifest.schema.json'
    $report.inputHash = Get-GuardTextHash $manifestPath
    $entries = if ($Stage -eq 'Pre') {
        @($PlannedPaths | ForEach-Object { [ordered]@{ status = 'P'; path = $_.Replace('\', '/') } })
    }
    else { @(Get-ChangedEntries $root $BaseRef $HeadRef) }
    $entries = @($entries | Where-Object { $null -ne $_ })
    foreach ($entry in $entries) {
        [void] (Resolve-GuardPath $root ([string] $entry.path))
        if ($entry.Contains('previousPath')) { [void] (Resolve-GuardPath $root ([string] $entry.previousPath)) }
    }
    $affected = Get-Affected $entries $manifest
    $report.ruleIds = $affected.rules
    if ($Stage -eq 'Pre') {
        if ($entries.Count -eq 0) { throw 'Pre requires -PlannedPaths.' }
        $areaChecks = @($affected.areas | ForEach-Object {
            $area = $_
            $match = @($affected.paths | Where-Object { Test-GuardGlob $_ $area.pathPattern })
            [ordered]@{ id = $area.id; layer = $area.layer; owner = Get-Owner $area.ownerSource $root $match[0]; focusedCommands = $area.focusedCommands; similarImplementationSearchRoot = $area.pathPattern.Replace('/**', ''); paths = $match }
        })
        $report.checks = @($areaChecks)
        $unknownPaths = @($affected.paths | Where-Object {
            $path = $_
            @($affected.areas | Where-Object { Test-GuardGlob $path $_.pathPattern }).Count -eq 0
        })
        if ($unknownPaths.Count -gt 0) { $report.checks += [ordered]@{ id = 'unmapped-paths'; status = 'advisory'; paths = $unknownPaths; suggestedValidation = 'Post Full' } }
        $report.checks += [ordered]@{ id = 'risk-classification'; status = 'advisory'; risks = @($affected.risks | ForEach-Object { [ordered]@{ id = $_.id; reason = $_.reason; requiresDecision = $_.requiresDecision } }) }
        $report.scope = 'planned-impact'
        $report.status = 'advisory'
        $report.reason = 'Planned impact only; code has not been verified. Search similar implementations in the affected area paths.'
        if (@($affected.risks | Where-Object { $_.requiresDecision }).Count -gt 0) {
            $decision = Test-DecisionCoverage $root $DecisionPath $affected.risks $affected.paths
            $report.checks += [ordered]@{ id = 'decision'; status = $(if ($decision.valid) { 'pass' } else { 'blocked' }); reason = $decision.reason }
            if (-not $decision.valid) { $report.status = 'blocked'; $report.reason = $decision.reason }
        }
    }
    elseif ($Stage -eq 'Diff') {
        $report.scope = if ($HeadRef) { "$BaseRef...$HeadRef" } elseif ($BaseRef) { "$BaseRef...worktree" } else { 'HEAD...worktree' }
        $checks = [Collections.Generic.List[object]]::new()
        $checks.Add([ordered]@{ id = 'changed-paths'; status = 'pass'; entries = $entries })
        $classified = @($entries | ForEach-Object {
            $entry = $_
            $entryPaths = @($entry.path)
            if ($entry.Contains('previousPath')) { $entryPaths += $entry.previousPath }
            [ordered]@{
                status = $entry.status
                path = $entry.path
                previousPath = $(if ($entry.Contains('previousPath')) { $entry.previousPath } else { '' })
                areas = @($manifest.areas | Where-Object {
                    $area = $_
                    @($entryPaths | Where-Object { Test-GuardGlob $_ $area.pathPattern }).Count -gt 0
                } | ForEach-Object { $_.id })
                riskIds = @($manifest.riskTriggers | Where-Object {
                    $trigger = $_
                    @($entryPaths | Where-Object { Test-GuardGlob $_ $trigger.pathPattern }).Count -gt 0
                } | ForEach-Object { $_.id })
                generated = (Test-GuardGlob $entry.path 'docs/guards/generated/**')
            }
        })
        $checks.Add([ordered]@{ id = 'classification'; status = 'pass'; entries = $classified })
        if ($DeclaredPaths.Count -gt 0) {
            foreach ($pattern in $DeclaredPaths) { Assert-GuardPattern $pattern }
            $outside = @($affected.paths | Where-Object {
                $path = $_
                @($DeclaredPaths | Where-Object { Test-GuardGlob $path $_ }).Count -eq 0
            })
            $checks.Add([ordered]@{ id = 'declared-scope'; status = $(if ($outside.Count -eq 0) { 'pass' } else { 'fail' }); pathsOutside = $outside; declaredPaths = $DeclaredPaths })
        }
        $risk = @($affected.risks | Where-Object { $_.requiresDecision })
        if ($risk.Count -gt 0) {
            $records = if ($DecisionPath.Count -gt 0) { @($DecisionPath) } else { @($affected.paths | Where-Object { Test-GuardGlob $_ 'docs/guards/decisions/*.json' }) }
            $decision = Test-DecisionCoverage $root $records $risk $affected.paths
            $checks.Add([ordered]@{ id = 'decision'; status = $(if ($decision.valid) { 'pass' } else { 'fail' }); riskIds = @($risk | ForEach-Object { $_.id }); reason = $decision.reason })
        }
        $deletions = @($entries | Where-Object {
            $_.status -eq 'D' -and (
                (Test-GuardGlob $_.path 'docs/guards/inputs/rules/*.json') -or
                (Test-GuardGlob $_.path 'scripts/guards/**') -or
                (Test-GuardGlob $_.path '.github/workflows/**') -or
                (Test-GuardGlob $_.path '.github/CODEOWNERS') -or
                (Test-GuardGlob $_.path 'docs/guards/contracts/**')
            )
        })
        if ($deletions.Count -gt 0) {
            $checks.Add([ordered]@{ id = 'protected-deletions'; status = 'fail'; paths = @($deletions | ForEach-Object { $_.path }); reason = 'Deleting a guard rule, runtime, contract, owner routing, or CI workflow requires a separate migration.' })
        }
        $report.checks = @($checks)
        $report.status = if (@($checks | Where-Object { $_.status -eq 'fail' }).Count -gt 0) { 'fail' } else { 'pass' }
        $report.reason = if ($report.status -eq 'pass') { 'Mechanical diff checks passed; intent and adequacy still require review.' } else { 'Mechanical diff checks failed.' }
    }
    else {
        $commandIds = @()
        $full = $Scope -eq 'Full' -or $affected.areas.Count -eq 0 -or
            @($affected.paths | Where-Object { Test-GuardGlob $_ 'src/Modules/**/IFX.Modules.*.Domain/**' }).Count -gt 0 -or
            @($affected.risks | Where-Object { $_.id -like 'guard-*' -or $_.id -eq 'gate-authority' -or $_.id -eq 'ci-workflow' }).Count -gt 0
        if (-not $full) {
            $areaIds = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($area in $affected.areas) { [void] $areaIds.Add([string] $area.id) }
            if ($Profile -eq 'ifx' -and @($affected.areas | Where-Object { $_.id -in @('IAM', 'CRM', 'Registry', 'Holdings', 'Transaction', 'Authentication', 'Authorization') }).Count -gt 0) {
                $ownership = Get-Content -LiteralPath (Resolve-GuardPath $root 'docs/architecture/review/gates/G03/generated/layerguard-governance-input.json' -MustExist) -Raw | ConvertFrom-Json -Depth 100
                do {
                    $previousCount = $areaIds.Count
                    foreach ($property in $ownership.providerContracts.PSObject.Properties) {
                        foreach ($provider in $property.Value) {
                            if ($areaIds.Contains([string] $provider)) { [void] $areaIds.Add([string] $property.Name) }
                        }
                    }
                } while ($areaIds.Count -gt $previousCount)
            }
            foreach ($area in $manifest.areas) {
                if ($areaIds.Contains([string] $area.id)) { $commandIds += @($area.focusedCommands) }
            }
            if ($areaIds.Contains('Frontend')) { $commandIds = @('frontend-install') + $commandIds }
        }
        if ($full) { $commandIds = @($manifest.postFullCommands) }
        $report.scope = if ($full) { 'full' } else { 'focused' }
        $commandIds = @($commandIds | Select-Object -Unique)
        if ($commandIds.Count -eq 0) { throw 'No Post commands selected.' }
        $selection = [ordered]@{ id = 'selection'; status = 'pass'; paths = $affected.paths; areas = @($affected.areas | ForEach-Object { $_.id }); commands = $commandIds; escalatedToFull = $full }
        if ($SkipCommands) {
            $report.status = 'not-run'
            $report.reason = 'Commands were skipped.'
            $report.checks = @($selection) + @($commandIds | ForEach-Object { [ordered]@{ id = $_; status = 'not-run' } })
        }
        else {
            $checks = [Collections.Generic.List[object]]::new()
            foreach ($id in $commandIds) {
                $command = @($manifest.commands | Where-Object { $_.id -eq $id })[0]
                $check = Invoke-GuardCommand $command $root $stageName $TimeoutSeconds
                $checks.Add($check)
                if ($check.status -ne 'pass') { break }
            }
            $report.checks = @($selection) + @($checks)
            $report.evidencePaths = @($checks | ForEach-Object { $_.evidencePaths })
            $report.status = if (@($checks | Where-Object { $_.status -eq 'blocked' }).Count -gt 0) { 'blocked' } elseif (@($checks | Where-Object { $_.status -eq 'fail' }).Count -gt 0) { 'fail' } elseif ($checks.Count -eq $commandIds.Count) { 'pass' } else { 'not-run' }
            $report.reason = if ($report.status -eq 'pass') { 'All selected commands passed.' } else { 'A selected command failed or could not run.' }
        }
    }
}
catch {
    $report.status = 'blocked'
    $report.reason = $_.Exception.Message
}
$json = ConvertTo-GuardJson $report
Write-GuardText $reportPath $json
if (-not (Test-Json -Path $reportPath -SchemaFile (Resolve-GuardPath $root 'docs/guards/contracts/guard-result.schema.json' -MustExist) -ErrorAction Stop)) {
    throw 'Guard result schema validation failed.'
}
Write-Host "Guard $Stage status: $($report.status). Report: $OutputPath"
if ($report.status -in @('blocked', 'fail', 'not-run')) { exit 1 }
