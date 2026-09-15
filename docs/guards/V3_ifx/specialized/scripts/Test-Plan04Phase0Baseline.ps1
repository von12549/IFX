[CmdletBinding()]
param(
    [string] $InputPath = 'docs/architecture/review/evidence/plan04/phase0-baseline-inputs.json',
    [string] $StatusPath = 'docs/architecture/review/evidence/plan04/phase0-baseline-status.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))

function Repo([string] $path) {
    if ([IO.Path]::IsPathRooted($path)) { return $path }
    return Join-Path $repositoryRoot $path
}

function Sha256([string] $path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath (Repo $path)).Hash.ToLowerInvariant()
}

$baseline = Get-Content -Raw -LiteralPath (Repo $InputPath) | ConvertFrom-Json -Depth 100
$planText = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/plans/04-module-boundary-evolution.md')
$b4 = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/evidence/layerguard/B4-report.json') | ConvertFrom-Json -Depth 100
$b4Status = Get-Content -Raw -LiteralPath (Repo 'docs/architecture/review/evidence/layerguard/B4-validation-status.json') | ConvertFrom-Json -Depth 100

$artifactChecks = @()
foreach ($authority in @($baseline.authorities)) {
    foreach ($artifact in @($authority.artifacts)) {
        $refresh = @($baseline.authorityRefreshes | Where-Object authority -EQ $authority.authority |
            ForEach-Object { $_.artifacts } | Where-Object path -EQ $artifact.path | Select-Object -Last 1)
        $expectedSha256 = if ($refresh.Count -eq 1) { [string]$refresh[0].sha256 } else { [string]$artifact.sha256 }
        $exists = Test-Path -LiteralPath (Repo $artifact.path) -PathType Leaf
        $actual = if ($exists) { Sha256 $artifact.path } else { $null }
        $artifactChecks += [ordered]@{
            authority = $authority.authority
            path = $artifact.path
            expectedSha256 = $expectedSha256
            actualSha256 = $actual
            binding = if ($refresh.Count -eq 1) { 'reviewed-authority-refresh' } else { 'phase0-freeze' }
            result = if ($exists -and $actual -eq $expectedSha256) { 'passed' } else { 'failed' }
        }
    }
}

$requiredAuthorities = @('G02', 'G03', 'G04', 'G05', 'LayerGuard-B4')
$requiredOwners = @('architecture', 'database', 'security', 'auth-application', 'crm-application',
    'registry-application', 'transaction-application', 'holdings-application', 'reporting-data', 'layerguard')
$requiredExcludedScope = @('TX6', 'DB5', 'DB6', 'DB7', 'DB12', 'DP8', 'DP9', 'GOV6', 'OPS2', 'OPS5')
$authorityNames = @($baseline.authorities.authority)
$ownerNames = @($baseline.owners.responsibility)
$missingCompletionSemantics = @('designComplete','repositoryGovernanceComplete','productionValidationComplete') |
    Where-Object { [string]::IsNullOrWhiteSpace([string]$baseline.completionSemantics.$_) }
$completionSemanticsSeparated = (@($missingCompletionSemantics).Count -eq 0) -and
    ([string]$baseline.completionSemantics.productionValidationComplete -match 'target environment')
$commitExists = $false
& git -C $repositoryRoot cat-file -e "$($baseline.baselineCommit)^{commit}" 2>$null
if ($LASTEXITCODE -eq 0) { $commitExists = $true }

$checks = [ordered]@{
    identityIsFrozen = $baseline.formatVersion -eq 1 -and $baseline.plan -eq '04-module-boundary-evolution' -and
        $baseline.slice -eq 'P04-S0' -and $baseline.baselineCommit -match '^[0-9a-f]{40}$' -and $commitExists
    authoritySetIsExact = @(Compare-Object $requiredAuthorities $authorityNames).Count -eq 0 -and
        @($authorityNames | Group-Object | Where-Object Count -ne 1).Count -eq 0
    authorityArtifactsAreHashBound = @($artifactChecks | Where-Object result -ne 'passed').Count -eq 0
    authorityRefreshesAreAppendOnlyAndScoped = @($baseline.authorityRefreshes | Where-Object {
        $_.authority -notin $requiredAuthorities -or [string]::IsNullOrWhiteSpace([string]$_.capturedAt) -or
        [string]::IsNullOrWhiteSpace([string]$_.reason) -or @($_.artifacts).Count -eq 0
    }).Count -eq 0
    ownerSetIsExactAndNamed = @(Compare-Object $requiredOwners $ownerNames).Count -eq 0 -and
        @($baseline.owners | Where-Object {
            [string]::IsNullOrWhiteSpace($_.deliveryOwner) -or [string]::IsNullOrWhiteSpace($_.contact) -or
            [string]::IsNullOrWhiteSpace($_.evidence) -or [string]::IsNullOrWhiteSpace($_.approvalStatus)
        }).Count -eq 0
    activeScopeIsExact = (@($baseline.activeScope | Sort-Object) -join ',') -eq ((@('GOV4','DP6','DB8','GOV3') | Sort-Object) -join ',')
    excludedScopeIsExact = @(Compare-Object $requiredExcludedScope @($baseline.excludedScope)).Count -eq 0
    completionSemanticsAreSeparated = $completionSemanticsSeparated
    productionClaimsAreNotClaimed = @($baseline.claims.psobject.Properties | Where-Object Value -ne 'not-claimed').Count -eq 0
    b4StrictBaselineMatches = $b4.toolVersion -eq $baseline.layerGuard.toolVersion -and
        $b4.verdict -eq $baseline.layerGuard.expectedVerdict -and
        $b4.violationCount -eq $baseline.layerGuard.expectedViolationCount -and
        $b4.baseline.totalEntries -eq $baseline.layerGuard.expectedWaiverCount -and
        $b4.scope.projectsInScope -eq $baseline.layerGuard.expectedProjectsInScope -and $b4Status.result -eq 'passed'
    phase0ChecklistIsClosed = @('ME0.1','ME0.2','ME0.3','ME0.4','ME0.5','ME0.6' | Where-Object {
        $planText -notmatch "- \[x\] $([regex]::Escape($_))"
    }).Count -eq 0 -and $planText -match '- \[x\] \*\*Phase 0 完成'
}

$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$status = [ordered]@{
    formatVersion = 1
    plan = '04-module-boundary-evolution'
    slice = 'P04-S0'
    result = if ($failed.Count -eq 0) { 'passed' } else { 'failed' }
    checkedAt = (Get-Date).ToString('yyyy-MM-dd')
    baselineCommit = $baseline.baselineCommit
    layerGuardVersion = $baseline.layerGuard.toolVersion
    checks = $checks
    artifacts = $artifactChecks
    phaseStatus = [ordered]@{
        phase0 = if ($failed.Count -eq 0) { 'passed' } else { 'failed' }
        phase1 = 'pending'
        phase2 = 'pending'
        phase3 = 'pending'
        phase4 = 'pending'
        phase5 = 'pending'
        phase6 = 'pending'
        phase7 = 'pending'
        phase8 = 'pending'
    }
    approvalStatus = [ordered]@{
        repositoryDeliveryOwnersRecorded = $true
        namedFunctionalApprovals = 'pending'
    }
    productionClaims = $baseline.claims
    failedChecks = $failed
}

$resolvedStatus = Repo $StatusPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedStatus) | Out-Null
$status | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $resolvedStatus -Encoding utf8NoBOM

if ($failed.Count -gt 0) {
    throw "Plan 04 Phase 0 baseline validation failed: $($failed -join ', '). Report: $resolvedStatus"
}

Write-Host "Plan 04 Phase 0 baseline validation passed. Report: $resolvedStatus"
