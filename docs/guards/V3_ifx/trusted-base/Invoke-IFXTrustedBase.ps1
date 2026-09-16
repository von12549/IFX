[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $HeadRoot,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string] $BaseSha,
    [Parameter(Mandatory)][ValidateSet('Validate', 'Pre', 'Diff', 'Architecture', 'Specialized', 'Quality', 'HistoricalIntegrity')][string] $Mode,
    [ValidateSet('G03', 'G04', 'G05', 'Plan04', 'Database', 'All')][string] $SpecializedGate = 'All',
    [ValidateSet('Solution', 'Assembly', 'Frontend', 'All')][string] $QualityTarget = 'All',
    [string] $PlanPath,
    [string] $BaseRef,
    [string] $HeadRef,
    [string] $OutputDirectory = 'artifacts/guards/v3-ifx',
    [string] $GenerationRoot,
    [string] $GateId
)

# Plan 06 §11.1 Trusted Base Guard Execution. This script must itself be started from a clean base worktree created
# outside the head checkout; the head checkout is only ever passed as -TargetRoot. Domain authorities from head are
# compared with base by role (§12.6) before candidate projections are generated in a directory outside head and base,
# and the guard dispatcher then runs from that base-derived candidate package.

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

    # ---- candidate package: base package files, plus projections regenerated from head authorities after anti-weakening checks
    $usesAuthorities = $Mode -in @('Validate', 'Architecture', 'Specialized')
    if ([IO.Directory]::Exists($candidateRepository)) { [IO.Directory]::Delete($candidateRepository, $true) }
    $packageFiles = Get-GuardPackageRepositoryFiles $baseRepository
    Copy-GuardFiles $baseRepository $candidateRepository $packageFiles
    $candidatePackage = Join-Path $candidateRepository 'docs/guards/V3_ifx'
    if ($usesAuthorities) {
        $authorityReport = Join-Path $trustedOutput "domain-authorities-$($Mode.ToLowerInvariant()).json"
        $authority = Invoke-GuardIsolatedPwsh (Join-Path $PSScriptRoot 'Test-IFXDomainAuthorityCandidates.ps1') @('-TargetRoot', $head, '-BaseRepository', $baseRepository, '-ReportPath', $authorityReport)
        Write-Host $authority.Output
        if ($authority.ExitCode -ne 0) {
            Add-Check 'domain-authority-candidates' 'fail' 'Head domain authorities change governing policy or widen exceptions (Plan 06 §12.6); candidate projections are not generated.' @($authorityReport)
            throw 'Domain authority candidates failed.'
        }
        Add-Check 'domain-authority-candidates' 'pass' $null @($authorityReport)

        $registry = Get-Content -LiteralPath (Join-Path $packageRoot 'policy/authorities.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $projectionTargets = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($projection in @(@($registry.projections) + @($registry.g04Bindings))) { [void]$projectionTargets.Add("docs/guards/V3_ifx/$($projection.target)") }
        $before = Get-GuardFileHashes $candidateRepository $packageFiles
        $sync = Invoke-GuardIsolatedPwsh (Join-Path $candidatePackage 'scripts/Sync-IFXPolicyInputs.ps1') @('-Mode', 'Generate', '-PackageRoot', $candidatePackage, '-TargetRoot', $head)
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

    # ---- guard run from the candidate package, with head only as the target
    $arguments = @('-Mode', $Mode, '-TargetRoot', $head, '-OutputDirectory', $output)
    switch ($Mode) {
        'Specialized' { $arguments += @('-SpecializedGate', $SpecializedGate) }
        'Quality' { $arguments += @('-QualityTarget', $QualityTarget) }
        # A formal Plan is the only Pre input a trusted run accepts; ad hoc path lists stay a local advisory command.
        'Pre' { if (-not $PlanPath) { throw 'Pre requires -PlanPath in a trusted base run.' }; $arguments += @('-PlanPath', $PlanPath) }
        'Diff' { $arguments += @('-PlanPath', $PlanPath, '-BaseRef', $BaseRef); if ($HeadRef) { $arguments += @('-HeadRef', $HeadRef) } }
    }
    $run = Invoke-GuardIsolatedPwsh (Join-Path $candidatePackage 'scripts/Invoke-IFXGuardrails.ps1') $arguments -WorkingDirectory $head
    Write-Host $run.Output
    $summaryName = switch ($Mode) { 'HistoricalIntegrity' { 'summary-historical-integrity.json' } default { "summary-$($Mode.ToLowerInvariant()).json" } }
    if ($run.ExitCode -eq 0) { Add-Check 'guardrails' 'pass' $null @((Join-Path $output $summaryName)) }
    else { Add-Check 'guardrails' 'fail' "Base guardrails returned exit code $($run.ExitCode)." @((Join-Path $output $summaryName)) }
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
$summaryPath = Join-Path $trustedOutput "summary-$($Mode.ToLowerInvariant()).json"
[IO.File]::WriteAllText($summaryPath, ($summary | ConvertTo-Json -Depth 10) + "`n", [Text.UTF8Encoding]::new($false))
if (-not (Test-Json -Path $summaryPath -SchemaFile (Join-Path $packageRoot 'contracts/trusted-base-summary.schema.json') -ErrorAction Stop)) { throw 'Trusted base summary does not match its schema.' }
foreach ($check in $checks) { if ($check.status -eq 'fail') { Write-Host "FAIL $($check.id): $($check.reason)" } }
if ($status -ne 'pass') { Write-Host "Trusted base run failed: $summaryPath"; exit 1 }
Write-Host "Trusted base run passed: $summaryPath"
