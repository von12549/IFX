[CmdletBinding()]
param(
    [string]$LayerGuardReportPath = "docs/architecture/review/evidence/layerguard/B1-report.json",
    [string]$BaselinePath = "mcp/LayerGuard/baselines/b1.json",
    [string]$StatusPath = "docs/architecture/review/evidence/03-a1-layerguard-policy-binding-status.json"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

function Resolve-RepoPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return Join-Path $repoRoot $Path
}

function Read-Json([string]$Path) {
    $resolved = Resolve-RepoPath $Path
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "Required 03-A1 artifact is missing: $resolved"
    }
    return Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json
}

$report = Read-Json $LayerGuardReportPath
$baseline = Read-Json $BaselinePath
$config = Read-Json "src/layerguard.json"
$plan03 = Get-Content -LiteralPath (Resolve-RepoPath "docs/architecture/review/plans/03-layerguard-alignment.md") -Raw
$master = Get-Content -LiteralPath (Resolve-RepoPath "docs/architecture/review/plans/00-master-plan.md") -Raw
$prerequisites = Get-Content -LiteralPath (Resolve-RepoPath "docs/architecture/review/plans/00-prerequisites.md") -Raw
$workflow = Get-Content -LiteralPath (Resolve-RepoPath ".github/workflows/layerguard.yml") -Raw

$checks = [ordered]@{}
$checks.toolVersion = $report.toolVersion -eq "0.4.0-a1"
$checks.baselineClean = $report.verdict -eq "baseline-clean"
$checks.findingInventory = $report.violationCount -eq 116 -and @($report.clusters).Count -eq 44
$checks.baselineMatch = $report.baseline.matched -eq 116 -and $report.baseline.new -eq 0 -and $report.baseline.stale -eq 0 -and $report.baseline.totalEntries -eq 116
$checks.gateBindings = @($report.ruleset.policyBindings).Count -eq 12 -and @($report.ruleset.policyBindings.gate) -contains "G03" -and @($report.ruleset.policyBindings.gate) -contains "G03-catalog" -and @($report.ruleset.policyBindings.gate) -contains "G04" -and @($report.ruleset.policyBindings.gate) -contains "G05"
$checks.policyHashFrozen = -not [string]::IsNullOrWhiteSpace($report.ruleset.hash) -and $baseline.rulesetHash -eq $report.ruleset.hash
$checks.waiverPolicyBound = $report.ruleset.waiverPolicy.maximumDays -eq 90 -and @($report.ruleset.waiverPolicy.unwaivableRules) -contains "OWNERSHIP-UNKNOWN" -and @($report.ruleset.waiverPolicy.unwaivableRules) -contains "PAYLOAD-TYPE-FORBIDDEN"
$checks.baselineAccountability = @($baseline.entries).Count -eq 116 -and @($baseline.entries | Where-Object { $_.owner -ne "@von12549" -or [string]::IsNullOrWhiteSpace($_.reason) -or [string]::IsNullOrWhiteSpace($_.removalCriteria) }).Count -eq 0
$checks.baselineLifetime = @($baseline.entries | Where-Object { (([datetime]$_.expiresOn) - ([datetime]$_.createdOn)).Days -gt 90 }).Count -eq 0
$checks.noUnwaivableDebt = @($baseline.entries | Where-Object { $_.rule -in @("OWNERSHIP-UNKNOWN", "PAYLOAD-TYPE-FORBIDDEN") }).Count -eq 0
$checks.directGateConfiguration = $null -ne $config.gatePolicies -and $config.PSObject.Properties.Name -notcontains "providerContracts"
$checks.semanticExclusionsExplicit = @($report.notChecked | Where-Object { $_ -like "Gate 05 field classification*" }).Count -eq 1
$checks.phase5Accepted = $plan03 -match '(?m)^- \[x\] \*\*Phase 5 完成\*\*' -and @(1..9 | Where-Object { $plan03 -notmatch "(?m)^- \[x\] L5\.$_ " }).Count -eq 0
$checks.masterPhase1Accepted = @(1..6 | Where-Object { $master -notmatch "(?m)^- \[x\] M1\.$_ " }).Count -eq 0
$checks.prerequisiteReleased = $prerequisites -match '(?m)^- \[x\] \*\*LG-POLICY-READY\*\*'
$checks.ciFailClosed = $workflow -match 'Invoke-G03ContractEventGuard\.ps1 -Phase 7' -and $workflow -match 'Invoke-LayerGuard\.ps1' -and $workflow -match 'Test-03A1PolicyBinding\.ps1'

$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$status = [ordered]@{
    formatVersion = 1
    plan = "03-A1"
    result = if ($failed.Count -eq 0) { "passed" } else { "failed" }
    milestone = "LG-POLICY-READY"
    checkedAt = (Get-Date).ToString("yyyy-MM-dd")
    checks = $checks
    metrics = [ordered]@{
        findings = $report.violationCount
        clusters = @($report.clusters).Count
        bindings = @($report.ruleset.policyBindings).Count
        baselineMatched = $report.baseline.matched
        baselineNew = $report.baseline.new
        baselineStale = $report.baseline.stale
        durationMs = $report.durationMs
    }
    policyHash = $report.ruleset.hash
    failedChecks = $failed
    remainingScope = @("03-B2", "03-B3", "03-B4", "Gate Final Closure")
}

$resolvedStatus = Resolve-RepoPath $StatusPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedStatus) | Out-Null
$status | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedStatus -Encoding utf8

if ($failed.Count -gt 0) {
    throw "03-A1 policy binding validation failed: $($failed -join ', '). Report: $resolvedStatus"
}

Write-Host "03-A1 LG-POLICY-READY validation passed: $resolvedStatus"
