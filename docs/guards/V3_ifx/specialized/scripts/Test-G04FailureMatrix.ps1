[CmdletBinding()]
param(
    [string] $MatrixPath = 'deployment/g04/failure-matrix.json',
    [string] $ReportPath = 'docs/architecture/review/evidence/gates/G04/G04-phase9-failure-matrix-report.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = if ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..')) }
function Repo([string] $path) { if ([IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $repositoryRoot $path } }
$matrix = Get-Content -Raw -LiteralPath (Repo $MatrixPath) | ConvertFrom-Json -Depth 100
$expected = @('database-preflight-failed','database-migrator-failed','worker-v2-not-ready','api-rolling-failed','api-v2-produced-before-rollback','transport-or-storage-outage','single-worker-crash','worker-fleet-failure','shutdown-timeout')
$ids = @($matrix.scenarios.scenarioId)
$requiredFieldsMissing = @($matrix.scenarios | Where-Object {
    [string]::IsNullOrWhiteSpace($_.module) -or [string]::IsNullOrWhiteSpace($_.dependency) -or
    [string]::IsNullOrWhiteSpace($_.role) -or [string]::IsNullOrWhiteSpace($_.reason) -or
    [string]::IsNullOrWhiteSpace($_.action) -or [string]::IsNullOrWhiteSpace($_.recovery)
})
$transport = $matrix.scenarios | Where-Object scenarioId -eq 'transport-or-storage-outage'
$v2 = $matrix.scenarios | Where-Object scenarioId -eq 'api-v2-produced-before-rollback'
$checks = [ordered]@{
    allRequiredScenariosPresent = @($expected | Where-Object { $_ -notin $ids }).Count -eq 0
    uniqueScenarioIds = @($ids | Select-Object -Unique).Count -eq $ids.Count
    operationalDimensionsComplete = $requiredFieldsMissing.Count -eq 0
    automaticDownProhibited = @($matrix.scenarios | Where-Object { 'automatic-down' -in $_.prohibitions }).Count -ge 2
    transportPreservesTruth = ('delete-outbox' -in $transport.prohibitions) -and ('invent-delivered' -in $transport.prohibitions)
    v2WorkerRetentionRequired = ('remove-v2-consumer' -in $v2.prohibitions) -and $v2.action -eq 'retain-v2-worker-while-api-rolls-back'
    shutdownRemainsBounded = ($matrix.scenarios | Where-Object scenarioId -eq 'shutdown-timeout').action -eq 'force-exit-after-grace'
}
$report = [ordered]@{ formatVersion=1; gate='G04'; phase=9; result=if($checks.Values -contains $false){'failed'}else{'passed'}; checks=$checks }
$resolved = Repo $ReportPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolved) | Out-Null
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolved -Encoding utf8NoBOM
if ($report.result -ne 'passed') { throw "G04 failure matrix validation failed: $resolved" }
Write-Host "G04 failure matrix validation passed: $resolved"
