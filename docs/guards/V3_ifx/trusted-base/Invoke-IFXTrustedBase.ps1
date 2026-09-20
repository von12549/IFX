[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $HeadRoot,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string] $BaseSha,
    [Parameter(Mandatory)][ValidateSet('Validate', 'Pre', 'Diff', 'Architecture', 'Specialized', 'Quality', 'HistoricalIntegrity', 'Scope')][string] $Mode,
    [ValidateSet('G03', 'G04', 'G05', 'Plan04', 'Database', 'All')][string] $SpecializedGate = 'All',
    [ValidateSet('Solution', 'Assembly', 'Frontend', 'All')][string] $QualityTarget = 'All',
    [string] $PlanPath,
    [string] $BaseRef,
    [string] $HeadRef,
    [string] $OutputDirectory = 'artifacts/guards/v3-ifx',
    [string] $GenerationRoot,
    [string] $GateId,
    # Scope mode appends `scope=<value>` for the workflow step that decides which head candidate work to skip (D28).
    [string] $GitHubOutput
)

# Plan 06 §11.1 Trusted Base Guard Execution. This script must itself be started from a clean base worktree created
# outside the head checkout; the head checkout is only ever passed as -TargetRoot. Domain authorities from head are
# compared with base by role (§12.6) before candidate projections are generated in a directory outside head and base,
# and the guard dispatcher then runs from that base-derived candidate package. With an explicit -HeadRef, authorities are
# compared as Git objects of that commit, and blocking findings pass only when the base protected change verifier covers
# them with base weaken-policy authorizations for that commit (D25). In Diff mode the base protected change
# verifier first checks that every protected obligation of the committed head is covered by exactly one base
# authorization that head deletes (Plan 06 §12.3, D22, D23); only its passing report, bound to base, merge base, head
# and the Diff protection configuration, is passed to the Diff stage, which exempts exactly the reported deletions.
# With an explicit -HeadRef, the base also classifies the verified changed set (D28): when every changed path is a formal
# plan document, an authorization record or a decision record, the gates whose inputs are entirely outside those
# artifacts inherit the verdict their inputs already have at the base instead of repeating the work. Classification is
# base-owned and fails closed to a full run; Validate, Pre, Diff, HistoricalIntegrity and the G03/G04/G05/Plan04 gates
# always run.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'TrustedBase.psm1') -Force
$packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$baseRepository = Get-GuardFullPath (Join-Path $packageRoot '../../..')
$head = Get-GuardFullPath $HeadRoot
$output = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $head $OutputDirectory }))
if (-not (Test-GuardPathWithin $output $head)) { throw 'OutputDirectory must stay under HeadRoot.' }
$trustedOutput = Join-Path $output 'trusted-base'
[void][IO.Directory]::CreateDirectory($trustedOutput)
$tempRoot = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { [IO.Path]::GetTempPath() }
$generation = if ($GenerationRoot) { Get-GuardFullPath $GenerationRoot } else { Get-GuardFullPath (Join-Path $tempRoot "guard-gen-$([Guid]::NewGuid().ToString('N').Substring(0, 8))") }
$candidateRepository = Join-Path $generation 'v3-ifx'
$checks = [Collections.Generic.List[object]]::new()
$headSha = $null
$gate = $null

function Add-Check([string] $Id, [string] $Status, [string] $Reason, [string[]] $EvidencePaths = @()) {
    $checks.Add([ordered]@{ id = $Id; status = $Status; reason = $Reason; evidencePaths = @($EvidencePaths | ForEach-Object { [IO.Path]::GetRelativePath($head, $_).Replace('\', '/') }) })
}
function Get-WorktreeState([string] $Repository) {
    return @(Invoke-GuardGit $Repository @('status', '--porcelain', '--ignored', '--untracked-files=all'))
}

# ---- Scope: classify the verified changed set and report nothing else (D28). The workflow calls this entry point from
# the base worktree, so an older base that does not know the mode simply fails the step, which means a full run.
if ($Mode -eq 'Scope') {
    if (-not $HeadRef) { throw 'Scope requires -HeadRef.' }
    $baseHead = @(Invoke-GuardGit $baseRepository @('rev-parse', 'HEAD'))
    if ($baseHead.Count -ne 1 -or $baseHead[0] -ne $BaseSha) { throw "The trusted base worktree is at $($baseHead -join ''), not $BaseSha." }
    $scopeArguments = @('-TargetRoot', $head, '-BaseSha', $BaseSha, '-HeadRevision', $HeadRef, '-ReportPath', (Join-Path $trustedOutput 'change-scope.json'))
    if ($GitHubOutput) { $scopeArguments += @('-GitHubOutput', $GitHubOutput) }
    $scopeOnly = Invoke-GuardIsolatedPwsh (Join-Path $PSScriptRoot 'Get-IFXChangeScope.ps1') $scopeArguments
    Write-Host $scopeOnly.Output
    exit $scopeOnly.ExitCode
}

try {
    # ---- base and head provenance
    $baseHead = @(Invoke-GuardGit $baseRepository @('rev-parse', 'HEAD'))
    if ($baseHead.Count -ne 1 -or $baseHead[0] -ne $BaseSha) { throw "The trusted base worktree is at $($baseHead -join ''), not $BaseSha." }
    $toplevel = Get-GuardFullPath (@(Invoke-GuardGit $baseRepository @('rev-parse', '--show-toplevel'))[0])
    if (-not (Get-GuardFullPath $toplevel).Equals($baseRepository, [StringComparison]::OrdinalIgnoreCase)) { throw "The trusted base package is not at the root of its worktree: $toplevel" }
    if ((Test-GuardPathWithin $baseRepository $head) -or (Test-GuardPathWithin $head $baseRepository)) { throw 'The base worktree and the head checkout must not contain each other.' }
    if ((Test-GuardPathWithin $generation $head) -or (Test-GuardPathWithin $generation $baseRepository) -or (Test-GuardPathWithin $head $generation) -or (Test-GuardPathWithin $baseRepository $generation)) { throw 'GenerationRoot must be outside the head checkout and the base worktree.' }
    $dirty = @(Get-WorktreeState $baseRepository)
    if ($dirty.Count -gt 0) { throw "The trusted base worktree is not clean: $($dirty | Select-Object -First 5)" }
    if ((Resolve-GuardCommit $head $BaseSha) -ne $BaseSha) { throw "The head repository does not contain base commit $BaseSha." }
    $headSha = Resolve-GuardCommit $head 'HEAD'
    if ($GateId) {
        $contract = $null
        foreach ($stageFile in Get-ChildItem -LiteralPath (Join-Path $packageRoot 'stages') -Filter stage.json -Recurse) {
            foreach ($declared in @((Get-Content -LiteralPath $stageFile.FullName -Raw | ConvertFrom-Json -AsHashtable -Depth 50).gates)) { if ($declared.id -eq $GateId) { $contract = $declared.trustContract } }
        }
        if ($null -eq $contract) { throw "Gate '$GateId' is not declared by the base stage manifests." }
        $gate = [ordered]@{ id = $GateId; type = $contract.type; guarantee = $contract.guarantee; knownGaps = @($contract.knownGaps) }
    }
    Add-Check 'base-provenance' 'pass' $null

    # ---- verified change scope: which gate work this pull request may inherit from its base (D28)
    $inheritable = ($Mode -in @('Architecture', 'Quality')) -or ($Mode -eq 'Specialized' -and $SpecializedGate -eq 'Database')
    $scope = 'full'
    $scopeReport = $null
    if ($HeadRef) {
        $scopeReport = Join-Path $trustedOutput "change-scope-$($Mode.ToLowerInvariant()).json"
        $scopeRun = Invoke-GuardIsolatedPwsh (Join-Path $PSScriptRoot 'Get-IFXChangeScope.ps1') @('-TargetRoot', $head, '-BaseSha', $BaseSha, '-HeadRevision', $HeadRef, '-ReportPath', $scopeReport)
        Write-Host $scopeRun.Output
        $scopeResult = if ([IO.File]::Exists($scopeReport)) { Get-Content -LiteralPath $scopeReport -Raw | ConvertFrom-Json } else { $null }
        if ($scopeRun.ExitCode -ne 0 -or $null -eq $scopeResult) { Add-Check 'change-scope' 'fail' "The change scope classification returned exit code $($scopeRun.ExitCode)." @(@($scopeReport) | Where-Object { [IO.File]::Exists($_) }); throw 'Change scope classification failed.' }
        $scope = [string]$scopeResult.scope
        Add-Check 'change-scope' 'pass' "$scope. $([string]$scopeResult.reason)" @($scopeReport)
    }
    else { Add-Check 'change-scope' 'skipped' 'Without an explicit head there is no verified changed set, so every gate repeats its work.' }

    # ---- candidate package: base package files, plus projections regenerated from head authorities after anti-weakening checks
    $usesAuthorities = $Mode -in @('Validate', 'Architecture', 'Specialized')
    if ([IO.Directory]::Exists($candidateRepository)) { [IO.Directory]::Delete($candidateRepository, $true) }
    $packageFiles = Get-GuardPackageRepositoryFiles $baseRepository
    Copy-GuardFiles $baseRepository $candidateRepository $packageFiles
    $candidatePackage = Join-Path $candidateRepository 'docs/guards/V3_ifx'
    if ($usesAuthorities) {
        $authorityReport = Join-Path $trustedOutput "domain-authorities-$($Mode.ToLowerInvariant()).json"
        $explicitHead = $null
        if ($HeadRef) {
            # D25: with an explicit pull request head, authorities are compared as Git objects of that commit and its merge base,
            # never through the checked-out (possibly synthetic merge) tree.
            $explicitHead = Resolve-GuardCommit $head $HeadRef
            $authorityMergeBase = @(Invoke-GuardGit $head @('merge-base', $BaseSha, $explicitHead) -AllowFailure)
            if ($LASTEXITCODE -ne 0 -or $authorityMergeBase.Count -ne 1) { throw 'Base and the explicit head have no single merge base; fetch complete history.' }
            $authorityMergeBase = $authorityMergeBase[0]
            $authority = Invoke-GuardIsolatedPwsh (Join-Path $PSScriptRoot 'Test-IFXDomainAuthorityCandidates.ps1') @('-TargetRoot', $head, '-BaseRevision', $authorityMergeBase, '-HeadRevision', $explicitHead, '-ReportPath', $authorityReport)
        }
        else { $authority = Invoke-GuardIsolatedPwsh (Join-Path $PSScriptRoot 'Test-IFXDomainAuthorityCandidates.ps1') @('-TargetRoot', $head, '-BaseRepository', $baseRepository, '-ReportPath', $authorityReport) }
        Write-Host $authority.Output
        $authorityResult = if ([IO.File]::Exists($authorityReport)) { Get-Content -LiteralPath $authorityReport -Raw | ConvertFrom-Json } else { $null }
        if ($authority.ExitCode -ne 0) {
            $blocking = @(if ($null -ne $authorityResult) { $authorityResult.authorities | Where-Object { @($_.blockingPointers).Count -gt 0 } })
            if (-not $HeadRef -or $blocking.Count -eq 0) {
                Add-Check 'domain-authority-candidates' 'fail' 'Head domain authorities change governing policy or widen exceptions (Plan 06 §12.6); without an explicit head and a covering base weaken-policy authorization, candidate projections are not generated.' @($authorityReport)
                throw 'Domain authority candidates failed.'
            }
            # D25: the base protected change verifier recomputes coverage for the explicit head from base records, algorithm
            # and registry; each blocking authority must be covered by exactly one consumed weaken-policy authorization.
            $coverageReport = Join-Path $generation "protected-changes-$($Mode.ToLowerInvariant()).json"
            $coverageEvidence = Join-Path $trustedOutput "protected-changes-$($Mode.ToLowerInvariant()).json"
            $coverage = Invoke-GuardIsolatedPwsh (Join-Path $PSScriptRoot 'Test-IFXProtectedChanges.ps1') @('-TargetRoot', $head, '-BaseSha', $BaseSha, '-HeadRevision', $explicitHead, '-ReportPath', $coverageReport)
            Write-Host $coverage.Output
            $problems = [Collections.Generic.List[string]]::new()
            if (-not [IO.File]::Exists($coverageReport)) { $problems.Add("The protected change verifier returned exit code $($coverage.ExitCode) without a report.") }
            else {
                [IO.File]::Copy($coverageReport, $coverageEvidence, $true)
                $covered = Get-Content -LiteralPath $coverageReport -Raw | ConvertFrom-Json
                $expectedBindings = [ordered]@{
                    baseSha = $BaseSha; mergeBase = $authorityMergeBase; headSha = $explicitHead
                    protectionSha256 = (Read-GuardProtection $packageRoot).Sha256
                    policyRegistrySha256 = Get-GuardSha256 ([IO.File]::ReadAllBytes((Join-Path $packageRoot 'shared/policy-config.json')))
                    authorizationSchemaSha256 = Get-GuardSha256 ([IO.File]::ReadAllBytes((Join-Path $packageRoot 'contracts/authorization.schema.json')))
                }
                foreach ($binding in $expectedBindings.GetEnumerator()) { if ([string]$covered.($binding.Key) -cne [string]$binding.Value) { $problems.Add("The coverage report is not bound to this run: $($binding.Key).") } }
                foreach ($item in $blocking) {
                    $obligation = @($covered.obligations | Where-Object { $_.id -ceq "policy-weakening:$($item.path)" })
                    $expectedPointers = (@($item.blockingPointers) | Sort-Object -Unique -CaseSensitive) -join "`n"
                    if ($obligation.Count -ne 1) { $problems.Add("Domain authority $($item.id) has no weakening obligation in the coverage report.") }
                    elseif (@($obligation[0].coveredBy).Count -ne 1) { $problems.Add("Domain authority $($item.id) blocking findings are not covered by exactly one base weaken-policy authorization: $($item.path) [$(@($item.blockingPointers) -join ', ')]") }
                    elseif (((@($obligation[0].pointers) | Sort-Object -Unique -CaseSensitive) -join "`n") -cne $expectedPointers) { $problems.Add("Domain authority $($item.id) coverage pointers differ from its blocking findings.") }
                }
            }
            if ($problems.Count -gt 0) {
                Add-Check 'domain-authority-candidates' 'fail' ($problems -join ' | ') @(@($authorityReport, $coverageEvidence) | Where-Object { [IO.File]::Exists($_) })
                throw 'Domain authority candidates failed.'
            }
            Add-Check 'domain-authority-candidates' 'pass' "Blocking findings covered by base weaken-policy authorizations for head ${explicitHead}: $(@($blocking | ForEach-Object { $_.path }) -join ', ')." @($authorityReport, $coverageEvidence)
        }
        else { Add-Check 'domain-authority-candidates' 'pass' $null @($authorityReport) }
        if ($HeadRef) {
            # Projections and gates read the checkout, so every changed authority there must equal the explicit head commit.
            $mismatched = [Collections.Generic.List[string]]::new()
            foreach ($item in @(if ($null -ne $authorityResult) { $authorityResult.authorities | Where-Object { $_.status -ne 'unchanged' } })) {
                $headText = Get-GuardBlobText $head $explicitHead ([string]$item.path)
                $checkoutFile = Join-Path $head ([string]$item.path)
                $checkoutText = if ([IO.File]::Exists($checkoutFile)) { [IO.File]::ReadAllText($checkoutFile) } else { $null }
                if (($null -eq $headText) -ne ($null -eq $checkoutText) -or ($null -ne $headText -and $headText.TrimStart([char]0xFEFF).Replace("`r`n", "`n") -cne $checkoutText.Replace("`r`n", "`n"))) { $mismatched.Add([string]$item.path) }
            }
            if ($mismatched.Count -gt 0) {
                Add-Check 'domain-authority-checkout' 'fail' "The checked-out authorities differ from the explicit head commit ${explicitHead}: $($mismatched -join ', ')"
                throw 'The checkout does not match the explicit head.'
            }
            Add-Check 'domain-authority-checkout' 'pass' $null
        }

        $registry = Get-Content -LiteralPath (Resolve-GuardAuthorityRegistryPath $packageRoot) -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $projectionTargets = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($projection in @(@($registry.projections) + @($registry.g04Bindings))) { [void]$projectionTargets.Add("docs/guards/V3_ifx/$($projection.target)") }
        $before = Get-GuardFileHashes $candidateRepository $packageFiles
        $sync = Invoke-GuardIsolatedPwsh (Join-Path $candidatePackage 'maintenance/Sync-IFXPolicyInputs.ps1') @('-Mode', 'Apply', '-AcceptMaintenance', '-PackageRoot', $candidatePackage, '-TargetRoot', $head)
        Write-Host $sync.Output
        if ($sync.ExitCode -ne 0) { Add-Check 'candidate-projection' 'fail' 'The base generator could not project head authorities.'; throw 'Candidate projection failed.' }
        $after = Get-GuardFileHashes $candidateRepository $packageFiles
        $changed = @($packageFiles | Where-Object { $before[$_] -ne $after[$_] })
        $unexpected = @($changed | Where-Object { -not $projectionTargets.Contains($_) })
        if ($unexpected.Count -gt 0) { Add-Check 'candidate-projection' 'fail' "The generator changed files outside registered projection targets: $($unexpected -join ', ')"; throw 'Candidate projection escaped its targets.' }
        Add-Check 'candidate-projection' 'pass' $(if ($changed.Count -gt 0) { "Regenerated from head authorities: $($changed -join ', ')" } else { $null })
    }
    else {
        Add-Check 'domain-authority-candidates' 'skipped' "Mode $Mode reads no domain authorities."
        Add-Check 'candidate-projection' 'skipped' "Mode $Mode uses base projections unchanged."
    }

    # ---- Diff: protected changes of a committed head must be covered by base authorizations that head deletes (D23)
    $guardEnvironment = @{}
    if ($Mode -eq 'Diff' -and -not $HeadRef) { Add-Check 'protected-changes' 'skipped' 'Uncommitted Diff: no authorization is honoured, so every protected deletion stays blocked.' }
    elseif ($Mode -eq 'Diff') {
        # The report the Diff stage reads stays outside head; a copy is kept under head as evidence.
        $protectedReport = Join-Path $generation 'protected-changes.json'
        $protectedEvidence = Join-Path $trustedOutput 'protected-changes-diff.json'
        $verifierArguments = @('-TargetRoot', $head, '-BaseSha', $BaseSha, '-HeadRevision', $HeadRef, '-ReportPath', $protectedReport)
        if ($PlanPath) { $verifierArguments += @('-PlanPath', $PlanPath) }
        $verification = Invoke-GuardIsolatedPwsh (Join-Path $PSScriptRoot 'Test-IFXProtectedChanges.ps1') $verifierArguments
        Write-Host $verification.Output
        $protectedResult = if ([IO.File]::Exists($protectedReport)) { [IO.File]::Copy($protectedReport, $protectedEvidence, $true); Get-Content -LiteralPath $protectedReport -Raw | ConvertFrom-Json } else { $null }
        # The runner re-checks the hashes that bind the report to the base registry and authorization schema (D24).
        $bindingProblems = @()
        if ($null -ne $protectedResult) {
            foreach ($binding in @(@('policyRegistrySha256', 'shared/policy-config.json'), @('authorizationSchemaSha256', 'contracts/authorization.schema.json'))) {
                $expected = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes((Join-Path $packageRoot $binding[1])))).ToLowerInvariant()
                if ([string]$protectedResult.($binding[0]) -cne $expected) { $bindingProblems += "The protected change report $($binding[0]) is not bound to the base $($binding[1])." }
            }
        }
        if ($verification.ExitCode -eq 0 -and $null -ne $protectedResult -and $protectedResult.status -eq 'pass' -and $bindingProblems.Count -eq 0) {
            $guardEnvironment['GUARD_PROTECTED_CHANGES'] = $protectedReport
            $covered = @($protectedResult.authorizations | ForEach-Object { "$($_.path) ($($_.status))" })
            $reason = if ($covered.Count -gt 0) { "Verified authorizations: $($covered -join ', ')." } else { 'No protected changes.' }
            Add-Check 'protected-changes' 'pass' $reason @($protectedEvidence)
        }
        else {
            $reasons = if ($null -ne $protectedResult) { @($protectedResult.failures) + $bindingProblems } else { @("The protected change verifier returned exit code $($verification.ExitCode) without a report.") }
            Add-Check 'protected-changes' 'fail' ($reasons -join ' | ') @(@($protectedEvidence) | Where-Object { [IO.File]::Exists($_) })
        }
        # Plan 06 §12.4 track two: head policy and configuration candidates are validated, never used for this verdict.
        $candidateReport = Join-Path $trustedOutput 'policy-candidates-diff.json'
        $candidates = Invoke-GuardIsolatedPwsh (Join-Path $PSScriptRoot 'Test-IFXPolicyCandidates.ps1') @('-TargetRoot', $head, '-BaseSha', $BaseSha, '-HeadRevision', $HeadRef, '-ReportPath', $candidateReport)
        Write-Host $candidates.Output
        if ($candidates.ExitCode -eq 0) { Add-Check 'policy-candidates' 'pass' $null @($candidateReport) }
        else {
            $candidateFailures = if ([IO.File]::Exists($candidateReport)) { @((Get-Content -LiteralPath $candidateReport -Raw | ConvertFrom-Json).failures) } else { @("The policy candidate validator returned exit code $($candidates.ExitCode) without a report.") }
            Add-Check 'policy-candidates' 'fail' ($candidateFailures -join ' | ') @(@($candidateReport) | Where-Object { [IO.File]::Exists($_) })
        }
    }

    # ---- guard run from the candidate package, with head only as the target
    $arguments = @('-Mode', $Mode, '-TargetRoot', $head, '-OutputDirectory', $output, '-GenerationRoot', $generation)
    switch ($Mode) {
        'Specialized' { $arguments += @('-SpecializedGate', $SpecializedGate) }
        'Quality' { $arguments += @('-QualityTarget', $QualityTarget) }
        # A formal Plan is the only Pre input a trusted run accepts; ad hoc path lists stay a local advisory command.
        'Pre' { if (-not $PlanPath) { throw 'Pre requires -PlanPath in a trusted base run.' }; $arguments += @('-PlanPath', $PlanPath) }
        'Diff' { $arguments += @('-PlanPath', $PlanPath, '-BaseRef', $BaseRef); if ($HeadRef) { $arguments += @('-HeadRef', $HeadRef) } }
    }
    # Trusted guard projects restore and build outside head and base (Plan 06 §11.2); head builds stay in head.
    $buildRoot = Join-Path $generation 'build'
    $headGuardBuild = Join-Path $head 'artifacts/build/v3-ifx'
    $headGuardBuildExisted = [IO.Directory]::Exists($headGuardBuild)
    $guardEnvironment['GUARD_BUILD_ROOT'] = $buildRoot
    if ($inheritable -and $scope -eq 'records-and-plans') {
        # The inputs of this gate are unchanged between the verified merge base and head, so its base verdict still holds.
        Add-Check 'trusted-build-isolation' 'skipped' 'The gate inherited its base verdict, so no guard build ran.'
        Add-Check 'guardrails' 'skipped' "Every changed path is a formal plan document, an authorization record or a decision record, so $Mode$(if ($Mode -eq 'Specialized') { " $SpecializedGate" } elseif ($Mode -eq 'Quality') { " $QualityTarget" }) inherits the verdict of base $BaseSha (D28)." @($scopeReport)
    }
    else {
        $run = Invoke-GuardIsolatedPwsh (Join-Path $candidateRepository 'docs/guards/V3_ifx/commands/Invoke-IFXGuardrails.ps1') $arguments -WorkingDirectory $head -Environment $guardEnvironment
        Write-Host $run.Output
        $summaryName = switch ($Mode) { 'HistoricalIntegrity' { 'summary-historical-integrity.json' } default { "summary-$($Mode.ToLowerInvariant()).json" } }
        if (-not $headGuardBuildExisted -and [IO.Directory]::Exists($headGuardBuild)) { Add-Check 'trusted-build-isolation' 'fail' 'Trusted guard build output was written into the head checkout.' }
        elseif ($headGuardBuildExisted) { Add-Check 'trusted-build-isolation' 'skipped' 'The head checkout already contained guard build output, so isolation could not be observed.' }
        else { Add-Check 'trusted-build-isolation' 'pass' $null }
        if ($run.ExitCode -eq 0) { Add-Check 'guardrails' 'pass' $null @((Join-Path $output $summaryName)) }
        else { Add-Check 'guardrails' 'fail' "Base guardrails returned exit code $($run.ExitCode)." @((Join-Path $output $summaryName)) }
    }
}
catch {
    if (@($checks | Where-Object { $_.status -eq 'fail' }).Count -eq 0) { Add-Check 'trusted-base' 'fail' $_.Exception.Message }
}
finally {
    # The base worktree must remain the clean, read-only source of the verdict chain.
    if ([IO.Directory]::Exists((Join-Path $baseRepository '.git')) -or [IO.File]::Exists((Join-Path $baseRepository '.git'))) {
        $after = @(Invoke-GuardGit $baseRepository @('status', '--porcelain', '--ignored', '--untracked-files=all') -AllowFailure)
        $afterHead = @(Invoke-GuardGit $baseRepository @('rev-parse', 'HEAD') -AllowFailure)
        if ($after.Count -gt 0 -or $afterHead.Count -ne 1 -or $afterHead[0] -ne $BaseSha) { Add-Check 'base-clean-after' 'fail' "The guard run modified the base worktree: $($after | Select-Object -First 5)" }
        else { Add-Check 'base-clean-after' 'pass' $null }
    }
    if (-not $GenerationRoot -and [IO.Directory]::Exists($generation)) { [IO.Directory]::Delete($generation, $true) }
}

$status = if (@($checks | Where-Object { $_.status -eq 'fail' }).Count -eq 0) { 'pass' } else { 'fail' }
$summary = [ordered]@{
    formatVersion = 1
    mode = $Mode
    status = $status
    baseSha = $BaseSha
    headSha = $headSha
    baseRepository = $baseRepository
    targetRoot = $head
    candidatePackage = if ($GenerationRoot) { $candidateRepository } else { $null }
    gate = $gate
    checks = @($checks)
}
$trustedSummaryName = switch ($Mode) {
    'Specialized' { "summary-specialized-$($SpecializedGate.ToLowerInvariant()).json" }
    'Quality' { "summary-quality-$($QualityTarget.ToLowerInvariant()).json" }
    default { "summary-$($Mode.ToLowerInvariant()).json" }
}
$summaryPath = Join-Path $trustedOutput $trustedSummaryName
[IO.File]::WriteAllText($summaryPath, ($summary | ConvertTo-Json -Depth 10) + "`n", [Text.UTF8Encoding]::new($false))
if (-not (Test-Json -Path $summaryPath -SchemaFile (Join-Path $packageRoot 'contracts/trusted-base-summary.schema.json') -ErrorAction Stop)) { throw 'Trusted base summary does not match its schema.' }
foreach ($check in $checks) { if ($check.status -eq 'fail') { Write-Host "FAIL $($check.id): $($check.reason)" } }
if ($status -ne 'pass') { Write-Host "Trusted base run failed: $summaryPath"; exit 1 }
Write-Host "Trusted base run passed: $summaryPath"
