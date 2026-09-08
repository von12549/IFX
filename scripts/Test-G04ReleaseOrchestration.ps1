[CmdletBinding()]
param(
    [string] $PlanPath = 'deployment/g04/release-orchestration.json',
    [string] $EvidencePath = 'deployment/g04/release-evidence-template.json',
    [string] $ReportPath = 'docs/architecture/review/evidence/gates/G04/G04-phase8-orchestration-report.json',
    [switch] $RequireCompleted
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
function Repo([string] $path) { if ([IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $repositoryRoot $path } }

$plan = Get-Content -Raw -LiteralPath (Repo $PlanPath) | ConvertFrom-Json -Depth 100
$evidence = Get-Content -Raw -LiteralPath (Repo $EvidencePath) | ConvertFrom-Json -Depth 100
$expected = @('database-preflight','restore-point','database-migrator','schema-validation','worker-consumer','api-producer','scheduler','observation','contract-cleanup')
$stageIds = @($plan.stages.stageId)
$evidenceIds = @($evidence.stages.stageId)
$index = @{}
for ($i = 0; $i -lt $stageIds.Count; $i++) { $index[$stageIds[$i]] = $i }
$dependencyErrors = @($plan.stages | ForEach-Object {
    $stage = $_
    @($stage.requires | Where-Object { -not $index.ContainsKey($_) -or $index[$_] -ge $index[$stage.stageId] })
})
$completedEvidenceValid = $true
$completedHeaderValid = $true
if ($RequireCompleted) {
    $placeholder = '^<.*>$'
    $completedHeaderValid = $evidence.status -eq 'completed' -and
        -not [string]::IsNullOrWhiteSpace($evidence.releaseId) -and $evidence.releaseId -notmatch $placeholder -and
        -not [string]::IsNullOrWhiteSpace($evidence.environment) -and $evidence.environment -notmatch $placeholder -and
        $evidence.artifactDigest -match '^(sha256:)?[a-fA-F0-9]{64}$' -and
        $evidence.runtimeManifestSha256 -match '^[a-fA-F0-9]{64}$' -and
        $evidence.migrationManifestSha256 -match '^[a-fA-F0-9]{64}$'

    foreach ($approval in @('architecture','moduleOwners','platform','database','security','operations')) {
        $reference = $evidence.approvals.$approval
        if ([string]::IsNullOrWhiteSpace($reference) -or $reference -match $placeholder -or $reference -notmatch '\d{4}-\d{2}-\d{2}') {
            $completedHeaderValid = $false
        }
    }

    $previousCompletion = [DateTimeOffset]::MinValue
    foreach ($stage in $evidence.stages) {
        if ($stage.status -ne 'succeeded' -or [string]::IsNullOrWhiteSpace($stage.evidence) -or $stage.evidence -match $placeholder) {
            $completedEvidenceValid = $false
            break
        }
        $started = [DateTimeOffset]::MinValue
        $completed = [DateTimeOffset]::MinValue
        $startedValid = [DateTimeOffset]::TryParse([string] $stage.startedAt, [ref] $started)
        $completedValid = [DateTimeOffset]::TryParse([string] $stage.completedAt, [ref] $completed)
        if (-not $startedValid -or -not $completedValid -or $started -lt $previousCompletion -or $completed -lt $started) {
            $completedEvidenceValid = $false
            break
        }
        $previousCompletion = $completed
    }
}
$checks = [ordered]@{
    exactConsumerFirstStages = ($stageIds -join ',') -eq ($expected -join ',')
    uniqueStageIds = @($stageIds | Select-Object -Unique).Count -eq $stageIds.Count
    dependenciesReferenceEarlierStages = $dependencyErrors.Count -eq 0
    evidenceMatchesPlan = ($evidenceIds -join ',') -eq ($stageIds -join ',')
    migratorStopsWithoutDown = ($plan.stages | Where-Object stageId -eq 'database-migrator').failureAction -eq 'stop-no-down'
    workerPrecedesApi = $index['worker-consumer'] -lt $index['api-producer']
    cleanupRequiresObservation = 'observation' -in @($plan.stages | Where-Object stageId -eq 'contract-cleanup').requires
    dataJobsAreSeparateAndOwned = @($plan.dataJobs).Count -eq 4 -and @($plan.dataJobs | Where-Object { [string]::IsNullOrWhiteSpace($_.owner) -or -not $_.idempotencyRequired -or $_.automatic }).Count -eq 0
    completedEvidenceValid = $completedEvidenceValid
    completedHeaderValid = $completedHeaderValid
}
$report = [ordered]@{
    formatVersion = 1
    gate = 'G04'
    phase = 8
    result = if ($checks.Values -contains $false) { 'failed' } else { 'passed' }
    validationMode = if ($RequireCompleted) { 'completed-release' } else { 'structure-only-no-production-claim' }
    checks = $checks
}
$resolvedReport = Repo $ReportPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReport) | Out-Null
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedReport -Encoding utf8NoBOM
if ($report.result -ne 'passed') { throw "G04 release orchestration validation failed: $resolvedReport" }
Write-Host "G04 release orchestration validation passed: $resolvedReport"
