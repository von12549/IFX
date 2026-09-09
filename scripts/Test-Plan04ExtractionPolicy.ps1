[CmdletBinding()]
param(
    [string] $PolicyPath = 'docs/architecture/review/policies/plan04/microservice-extraction-policy.json',
    [string] $FixtureDirectory = 'tests/Architecture/Plan04/Fixtures',
    [string] $StatusPath = 'docs/architecture/review/evidence/plan04/phase3-extraction-policy-status.json',
    [switch] $RequireApproval
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
function Repo([string] $path) {
    if ([IO.Path]::IsPathRooted($path)) { return $path }
    return Join-Path $repositoryRoot $path
}
function Sha256([string] $path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath (Repo $path)).Hash.ToLowerInvariant()
}
function Text-Present([object] $value) { return -not [string]::IsNullOrWhiteSpace([string]$value) }
function Sets-Equal([object[]] $left, [object[]] $right) {
    return (@($left | Sort-Object) -join "`n") -eq (@($right | Sort-Object) -join "`n")
}

$policy = Get-Content -Raw -LiteralPath (Repo $PolicyPath) | ConvertFrom-Json -Depth 100
$schemaPath = 'docs/architecture/review/policies/plan04/extraction-decision-record.schema.json'
$schema = Get-Content -Raw -LiteralPath (Repo $schemaPath) | ConvertFrom-Json -Depth 100
$hardGateIds = @($policy.hardGates.id)
$scoreIds = @($policy.evidenceDimensions.id)

function Validate-Record([object] $record) {
    $errors = [Collections.Generic.HashSet[string]]::new()
    if (-not (Text-Present $record.businessOwner) -or -not (Text-Present $record.dataOwner) -or -not (Text-Present $record.operationsOwner)) {
        [void]$errors.Add('owner-missing')
    }
    $recordGateIds = @($record.hardGates.id)
    if (-not (Sets-Equal $hardGateIds $recordGateIds)) { [void]$errors.Add('hard-gates-incomplete') }
    $failedGates = @($record.hardGates | Where-Object passed -ne $true)
    if ($failedGates.Count -gt 0) {
        [void]$errors.Add('hard-gate-failed')
        if ($record.targetState -in @('candidate','approved','executing','extracted')) { [void]$errors.Add('score-cannot-override-hard-gate') }
    }
    $recordScoreIds = @($record.evidenceScores.id)
    if (-not (Sets-Equal $scoreIds $recordScoreIds) -or @($record.evidenceScores | Where-Object {
        $_.value -lt 0 -or $_.value -gt 5 -or -not (Text-Present $_.evidence)
    }).Count -gt 0) { [void]$errors.Add('scores-incomplete') }
    if (@($policy.applicationRequirements | Where-Object { -not (Text-Present $record.$_) }).Count -gt 0) {
        [void]$errors.Add('application-evidence-incomplete')
    }
    $transition = @($policy.transitions | Where-Object { $_.from -eq $record.currentState -and $_.to -eq $record.targetState })
    if ($transition.Count -ne 1) {
        [void]$errors.Add('invalid-state-transition')
    }
    else {
        $approvedRoles = @($record.approvals | Where-Object {
            $_.status -eq 'approved' -and (Text-Present $_.approver) -and (Text-Present $_.evidence)
        } | Select-Object -ExpandProperty role)
        if (-not (Sets-Equal @($transition[0].approvals) $approvedRoles)) {
            [void]$errors.Add('transition-approvals-incomplete')
        }
    }
    return @($errors | Sort-Object)
}

$fixtureResults = @()
foreach ($file in @(Get-ChildItem -LiteralPath (Repo $FixtureDirectory) -File -Filter 'extraction-*.json' | Sort-Object Name)) {
    $record = Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json -Depth 100
    $actual = @(Validate-Record $record)
    $expected = @($record.expectedErrors | Sort-Object)
    $fixtureResults += [ordered]@{
        fixture = $file.Name
        expectedErrors = $expected
        actualErrors = $actual
        passed = Sets-Equal $expected $actual
    }
}

$requiredHardGates = @('HG1','HG2','HG3','HG4','HG5','HG6','HG7')
$requiredDimensions = @('team-autonomy','scaling-difference','release-frequency','failure-isolation-benefit','data-migration-complexity','latency-availability-fit','compliance-requirement')
$requiredStates = @('retain','observe','candidate','approved','executing','extracted')
$requiredPolicyApprovals = @('architecture','module-owner','platform','database','security','operations')
$approvalComplete = (Sets-Equal $requiredPolicyApprovals @($policy.approvals.role)) -and
    @($policy.approvals | Where-Object {
        $_.status -ne 'approved' -or -not (Text-Present $_.approver) -or -not (Text-Present $_.evidence)
    }).Count -eq 0
$checks = [ordered]@{
    schemaDeclaresRequiredRecord = $schema.properties.formatVersion.const -eq 1 -and
        @('businessOwner','dataOwner','operationsOwner','hardGates','evidenceScores','rollbackPath','modularMonolithAlternative' | Where-Object { $_ -notin @($schema.required) }).Count -eq 0
    exactHardGates = (Sets-Equal $requiredHardGates $hardGateIds) -and @($policy.hardGates | Where-Object required -ne $true).Count -eq 0
    exactEvidenceDimensions = Sets-Equal $requiredDimensions $scoreIds
    scoreCannotOverrideHardGate = $policy.scorePolicy.mayOverrideHardGate -eq $false -and $null -eq $policy.scorePolicy.approvalThreshold
    exactStateMachine = (Sets-Equal $requiredStates @($policy.states)) -and
        @($policy.transitions | Where-Object { $_.from -notin $requiredStates -or $_.to -notin $requiredStates -or @($_.approvals).Count -eq 0 }).Count -eq 0
    approvedStateRequiredBeforeExecution = $policy.executionPrerequisites.requiredState -eq 'approved' -and
        (Sets-Equal @('DP8-runtime-resilience','DP9-package-cadence') @($policy.executionPrerequisites.handoffs)) -and
        @($policy.executionPrerequisites.mustExistBeforeExecuting).Count -ge 6
    completeApplicationEvidenceRequired = @($policy.applicationRequirements).Count -eq 7 -and
        'rollbackPath' -in @($policy.applicationRequirements) -and 'modularMonolithAlternative' -in @($policy.applicationRequirements)
    positiveAndNegativeFixturesPass = $fixtureResults.Count -ge 5 -and @($fixtureResults | Where-Object passed -ne $true).Count -eq 0 -and
        @($fixtureResults | Where-Object { @($_.actualErrors).Count -eq 0 }).Count -eq 1
    defaultRemainsModularMonolith = $policy.defaultDeployment -eq 'modular-monolith' -and $policy.rollbackRule -match 'modular monolith'
}
$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$repositoryPassed = $failed.Count -eq 0
$status = [ordered]@{
    formatVersion = 1
    plan = '04-module-boundary-evolution'
    slice = 'P04-S3'
    result = if (-not $repositoryPassed) { 'failed' } elseif ($approvalComplete) { 'passed' } else { 'repository-passed-policy-approval-pending' }
    checkedAt = (Get-Date).ToString('yyyy-MM-dd')
    policySha256 = Sha256 $PolicyPath
    schemaSha256 = Sha256 $schemaPath
    checks = $checks
    fixtureResults = $fixtureResults
    approvalComplete = $approvalComplete
    approvals = $policy.approvals
    currentModuleDecision = 'no-module-approved-for-extraction'
    dp8Dp9 = 'not-triggered'
    failedChecks = $failed
}
$resolvedStatus = Repo $StatusPath
$status | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $resolvedStatus -Encoding utf8NoBOM
if (-not $repositoryPassed) { throw "Plan 04 extraction policy validation failed: $($failed -join ', '). Report: $resolvedStatus" }
if ($RequireApproval -and -not $approvalComplete) { throw "Plan 04 extraction policy approvals are pending. Report: $resolvedStatus" }
Write-Host "Plan 04 extraction policy result: $($status.result). Report: $resolvedStatus"
