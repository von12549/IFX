[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $TargetRoot,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string] $BaseSha,
    [string] $HeadRevision = 'HEAD',
    [ValidateSet('Validate', 'HistoricalIntegrity', 'G03', 'G04', 'G05', 'Plan04')][string[]] $ParityModes = @('Validate', 'HistoricalIntegrity', 'G03', 'G04', 'G05', 'Plan04'),
    [string] $WorkRoot,
    [string] $ReportPath = 'artifacts/guards/v3-ifx/trusted-base/tcb-candidate.json'
)

# Plan 06 §11.5 Trusted Base Component candidate upgrade, verified from the base worktree:
#  1. map the verified changed set onto trusted components (base manifest, then head manifest for new paths);
#  2. fail on gitlinks and on executables the head would activate that neither manifest registers;
#  3. require exactly one base change-trusted-base authorization for the changed components, consumed by head
#     (the same record checks as the protected change verifier that the trusted Diff runs, D23);
#  4. run the base-owned validation suites against the head candidate with base tests overlaid;
#  5. compare base and candidate guard verdicts on a fixed corpus (parity).
# The current PR's verdicts never come from the candidate.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'TrustedBase.psm1') -Force
$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$baseRepository = Get-GuardFullPath (Join-Path $packageRoot '../../..')
$target = Get-GuardFullPath $TargetRoot
$report = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $target $ReportPath }))
if (-not (Test-GuardPathWithin $report $target)) { throw 'ReportPath must stay under TargetRoot.' }
$tempRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$work = if ($WorkRoot) { Get-GuardFullPath $WorkRoot } else { Get-GuardFullPath (Join-Path $tempRoot "guard-tcb-$([Guid]::NewGuid().ToString('N').Substring(0, 8))") }
$manifestPath = 'docs/guards/V3_ifx/shared/trusted-components.json'
$failures = [Collections.Generic.List[string]]::new()
$result = [ordered]@{
    formatVersion = 1
    check = 'tcb-candidate'
    status = 'pass'
    baseSha = $BaseSha
    headSha = $null
    components = @()
    changes = @()
    authorization = $null
    validation = @()
    parity = @()
    failures = @()
}
$candidate = Join-Path $work 'candidate'
$candidateAdded = $false

function Format-Change([object] $Change) { return [ordered]@{ path = $Change.Path; component = $Change.Component; source = $Change.Source; base = $Change.Base; head = $Change.Head } }
function Get-SummaryChecks([string] $Path) {
    if (-not [IO.File]::Exists($Path)) { return 'summary-missing' }
    return (@((Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json).checks | ForEach-Object { "$($_.id)=$($_.status)" }) -join ',')
}

try {
    $packageHead = @(Invoke-GuardGit $baseRepository @('rev-parse', 'HEAD'))
    if ($packageHead.Count -ne 1 -or $packageHead[0] -ne $BaseSha) { throw "The verifier must run from the base commit $BaseSha, not $($packageHead -join '')." }
    if ((Test-GuardPathWithin $work $target) -or (Test-GuardPathWithin $work $baseRepository)) { throw 'WorkRoot must be outside the target and the base worktree.' }
    if ((Resolve-GuardCommit $target $BaseSha) -ne $BaseSha) { throw "Target repository does not contain base commit $BaseSha." }
    $headSha = Resolve-GuardCommit $target $HeadRevision
    $result.headSha = $headSha
    [void](Invoke-GuardGit $target @('merge-base', '--is-ancestor', $BaseSha, $headSha) -AllowFailure)
    if ($LASTEXITCODE -ne 0) { throw "Base $BaseSha is not an ancestor of head $headSha." }

    $baseManifest = Get-Content -LiteralPath (Join-Path $baseRepository $manifestPath) -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $headManifest = Read-GuardJsonBlob $target $headSha $manifestPath
    $tcb = Get-GuardTcbChanges $target $BaseSha $headSha $baseManifest $headManifest
    $result.components = @($tcb.Components)
    $result.changes = @($tcb.Changes | ForEach-Object { Format-Change $_ })
    foreach ($gitlink in $tcb.Gitlinks) { $failures.Add("Gitlink (mode 160000) in the protected scope: $gitlink") }
    foreach ($reference in (Get-GuardHeadExecutableReferences $target $headSha)) {
        $inBase = $null -ne (Get-GuardTcbComponentFor $baseManifest $reference)
        $inHead = $null -ne (Get-GuardTcbComponentFor $headManifest $reference)
        if (-not $inBase -and -not $inHead) { $failures.Add("Head activates an executable that no trusted component manifest registers: $reference") }
        elseif (-not $inBase -and 'tcb.manifest' -notin $tcb.Components) { $failures.Add("Head activates $reference, registered only by an unchanged head manifest.") }
    }

    if ($tcb.Components.Count -gt 0 -and $failures.Count -eq 0) {
        # ---- authorization: exactly one base record for this component set, deleted by head
        $authorizationRoot = Join-Path $baseRepository $AuthorizationDirectory
        $matching = [Collections.Generic.List[object]]::new()
        if ([IO.Directory]::Exists($authorizationRoot)) {
            foreach ($file in @(Get-ChildItem -LiteralPath $authorizationRoot -Filter '*.json' -File)) {
                if (-not (Test-GuardJsonSchema -Schema (Resolve-GuardContractPath $packageRoot 'authorization') -Path $file.FullName)) { $failures.Add("Base authorization does not match its schema: $($file.Name)"); continue }
                $record = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable -Depth 50
                if ("$($record.id).json" -cne $file.Name) { $failures.Add("Authorization file name must equal its id: $($file.Name)"); continue }
                if ($record.operation -ne 'change-trusted-base') { continue }
                $recordComponents = [string[]]@($record.components | Sort-Object -Unique -CaseSensitive)
                if (($recordComponents -join "`n") -ceq ($tcb.Components -join "`n")) { $matching.Add([pscustomobject]@{ Path = "$($AuthorizationDirectory)$($file.Name)"; Record = $record }) }
            }
        }
        if ($matching.Count -eq 0) { $failures.Add("Trusted component changes require a base change-trusted-base authorization for: $($tcb.Components -join ', ')") }
        elseif ($matching.Count -gt 1) { $failures.Add("More than one base authorization matches components $($tcb.Components -join ', '): $(($matching | ForEach-Object Path) -join ', ')") }
        else {
            $authorization = $matching[0]
            $record = $authorization.Record
            $result.authorization = $authorization.Path
            $consumed = @($tcb.Authorizations | Where-Object { $_.Path -ceq $authorization.Path -and $null -eq $_.Head })
            if ($consumed.Count -ne 1) { $failures.Add("Head must delete the consumed authorization $($authorization.Path).") }
            foreach ($failure in (Test-GuardTrustedBaseRecord $target $headSha $record $tcb $baseManifest $headManifest)) { $failures.Add($failure) }
            [string[]] $authorizedSuite = @($record.validationSuite | Sort-Object -Unique -CaseSensitive)

            if ($failures.Count -eq 0) {
                # ---- base-owned validation of the head candidate
                [void][IO.Directory]::CreateDirectory($work)
                [void](Invoke-GuardGit $target @('worktree', 'add', '--detach', $candidate, $headSha))
                $candidateAdded = $true
                $overlay = [Collections.Generic.List[string]]::new()
                foreach ($component in @($baseManifest.components | Where-Object { $_.status -eq 'active' -and ([string]$_.type).StartsWith('base-owned') })) {
                    foreach ($componentPath in $component.paths) {
                        $files = if ($componentPath.EndsWith('/')) { @(Invoke-GuardGitNul $baseRepository @('ls-files', '-z', '--', $componentPath)) } else { @($componentPath) }
                        foreach ($file in $files) { $overlay.Add($file) }
                    }
                }
                Copy-GuardFiles $baseRepository $candidate $overlay.ToArray()
                $validation = [Collections.Generic.List[object]]::new()
                foreach ($item in $authorizedSuite) {
                    if ($item -notmatch '^docs/guards/\S+\.ps1$') { $validation.Add([ordered]@{ entry = $item; status = 'external'; exitCode = $null }); continue }
                    $script = Join-Path $candidate $item
                    if (-not [IO.File]::Exists($script)) { $validation.Add([ordered]@{ entry = $item; status = 'fail'; exitCode = $null }); $failures.Add("Validation suite entry is missing from the candidate: $item"); continue }
                    $run = Invoke-GuardIsolatedPwsh $script @() -WorkingDirectory $candidate
                    $status = if ($run.ExitCode -eq 0) { 'pass' } else { 'fail' }
                    $validation.Add([ordered]@{ entry = $item; status = $status; exitCode = $run.ExitCode })
                    if ($status -eq 'fail') { $failures.Add("Base-owned validation failed on the candidate: $item (exit $($run.ExitCode)): $(($run.Output -split "`n" | Select-Object -Last 8) -join ' | ')") }
                }
                $result.validation = @($validation)

                # ---- parity on the fixed corpus: same target, base package versus candidate package
                $allowed = @{}
                foreach ($difference in @($record.allowedBehaviorDifferences)) { $allowed[$difference.mode] = $difference.reason }
                $parity = [Collections.Generic.List[object]]::new()
                foreach ($mode in $ParityModes) {
                    $arguments = if ($mode -match '^(G03|G04|G05|Plan04)$') { @('-Mode', 'Specialized', '-SpecializedGate', $mode) } else { @('-Mode', $mode) }
                    $summaryName = switch ($mode) { 'HistoricalIntegrity' { 'summary-historical-integrity.json' } 'Validate' { 'summary-validate.json' } default { 'summary-specialized.json' } }
                    $outcomes = @{}
                    foreach ($side in @('base', 'candidate')) {
                        $runner = if ($side -eq 'base') { Join-Path $packageRoot 'commands/Invoke-IFXGuardrails.ps1' } else { Join-Path $candidate 'docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1' }
                        $output = Join-Path $candidate "artifacts/guards/v3-ifx-tcb-parity/$side/$($mode.ToLowerInvariant())"
                        $run = Invoke-GuardIsolatedPwsh $runner ($arguments + @('-TargetRoot', $candidate, '-OutputDirectory', $output)) -WorkingDirectory $candidate
                        $summary = Join-Path $output $summaryName
                        $schemaValid = [IO.File]::Exists($summary) -and (Test-GuardJsonSchema -Schema (Resolve-GuardContractPath $packageRoot 'guard-summary') -Path $summary)
                        $outcomes[$side] = [ordered]@{ exitCode = $run.ExitCode; checks = (Get-SummaryChecks $summary); schemaValid = [bool]$schemaValid }
                    }
                    $equal = $outcomes.base.exitCode -eq $outcomes.candidate.exitCode -and $outcomes.base.checks -ceq $outcomes.candidate.checks -and $outcomes.candidate.schemaValid
                    $status = if ($equal) { 'equal' } elseif ($allowed.ContainsKey($mode) -and $outcomes.candidate.schemaValid) { 'allowed-difference' } else { 'different' }
                    $parity.Add([ordered]@{ mode = $mode; status = $status; base = $outcomes.base; candidate = $outcomes.candidate })
                    if ($status -eq 'different') { $failures.Add("Parity failed for ${mode}: base exit $($outcomes.base.exitCode) [$($outcomes.base.checks)], candidate exit $($outcomes.candidate.exitCode) [$($outcomes.candidate.checks)], candidate summary schema valid: $($outcomes.candidate.schemaValid)") }
                }
                $result.parity = @($parity)
            }
        }
    }
}
catch {
    $failures.Add($_.Exception.Message)
}
finally {
    if ($candidateAdded) { [void](Invoke-GuardGit $target @('worktree', 'remove', '--force', $candidate) -AllowFailure) }
    [void](Invoke-GuardGit $target @('worktree', 'prune') -AllowFailure)
    if (-not $WorkRoot -and [IO.Directory]::Exists($work)) { [IO.Directory]::Delete($work, $true) }
}

$result.failures = @($failures)
$result.status = if ($failures.Count -eq 0) { 'pass' } else { 'fail' }
[void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($report))
[IO.File]::WriteAllText($report, ($result | ConvertTo-Json -Depth 20) + "`n", [Text.UTF8Encoding]::new($false))
if ($failures.Count -gt 0) {
    foreach ($failure in $failures) { Write-Host "FAIL $failure" }
    Write-Host "Trusted component candidate check failed: $report"
    exit 1
}
$state = if ($result.components.Count -eq 0) { 'no trusted component changes' } else { "authorized change of $($result.components -join ', ')" }
Write-Host "Trusted component candidate check passed ($state): $report"
