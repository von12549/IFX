[CmdletBinding()]
param([string] $ReportPath = 'docs/architecture/review/evidence/gates/G04/G04-phase1-manifest-report.json')

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
function Repo([string] $path) { Join-Path $repositoryRoot $path }
function Sha([string] $path) { (Get-FileHash -Algorithm SHA256 -LiteralPath (Repo $path)).Hash.ToLowerInvariant() }

& (Join-Path $PSScriptRoot 'New-G04ReleaseManifest.ps1')
$first = Sha 'deployment/g04/release-runtime-manifest.json'
& (Join-Path $PSScriptRoot 'New-G04ReleaseManifest.ps1')
$second = Sha 'deployment/g04/release-runtime-manifest.json'

$modules = Get-Content -Raw -LiteralPath (Repo 'deployment/g04/module-manifest.json') | ConvertFrom-Json -Depth 100
$units = Get-Content -Raw -LiteralPath (Repo 'deployment/g04/deployment-unit-catalog.json') | ConvertFrom-Json -Depth 100
$compatibility = Get-Content -Raw -LiteralPath (Repo 'deployment/g04/infrastructure-compatibility-matrix.json') | ConvertFrom-Json -Depth 100
$release = Get-Content -Raw -LiteralPath (Repo 'deployment/g04/release-runtime-manifest.json') | ConvertFrom-Json -Depth 100
$dependencies = Get-Content -Raw -LiteralPath (Repo 'deployment/g04/dependency-criticality-catalog.json') | ConvertFrom-Json -Depth 100
$backpressure = Get-Content -Raw -LiteralPath (Repo 'deployment/g04/backpressure-policy.json') | ConvertFrom-Json -Depth 100
$moduleIds = @($modules.modules.moduleId)
$unitIds = @($units.units.unitId)
$bindingChecks = @($release.bindings.psobject.Properties | ForEach-Object { $_.Value.sha256 -eq (Sha $_.Value.path) })
$checks = [ordered]@{
    deterministicReleaseManifest = $first -eq $second
    exactRequiredModuleSet = (@($moduleIds | Sort-Object) -join ',') -eq 'auth,crm,holdings,registry,transaction'
    allModulesRequired = @($modules.modules | Where-Object { -not $_.required }).Count -eq 0
    uniqueModuleIdentity = @($moduleIds | Select-Object -Unique).Count -eq $moduleIds.Count
    uniqueEndpointIdentity = @($modules.modules.endpointGroups | Group-Object | Where-Object Count -gt 1).Count -eq 0
    uniqueDeploymentUnitIdentity = @($unitIds | Select-Object -Unique).Count -eq $unitIds.Count
    allRequiredUnitsPresent = @('ifx-api','ifx-worker','ifx-all','ifx-frontend','sqlserver','sqlserver-init','ifx-database-migrator','opa','cognito','sendgrid' | Where-Object { $_ -notin $unitIds }).Count -eq 0
    apiWorkerSameArtifact = (@($units.units | Where-Object unitId -in @('ifx-api','ifx-worker')).artifact | Select-Object -Unique).Count -eq 1
    releaseRequiredModulesMatch = (@($release.requiredModuleIds | Sort-Object) -join ',') -eq (@($moduleIds | Sort-Object) -join ',')
    releaseBindingsMatch = $bindingChecks -notcontains $false
    infrastructureOwnersComplete = @($compatibility.dependencies | Where-Object { [string]::IsNullOrWhiteSpace($_.owner) -or [string]::IsNullOrWhiteSpace($_.upgradeResponsibility) }).Count -eq 0
    schemaExists = Test-Path (Repo 'deployment/g04/module-manifest.schema.json')
    adrExists = Test-Path (Repo 'docs/architecture/review/gates/G04/ADR-G04-001-deployment-runtime-boundary.md')
    dependencyIdentitiesUnique = @($dependencies.dependencies.dependencyId | Select-Object -Unique).Count -eq @($dependencies.dependencies).Count
    dependencyCriticalitiesKnown = @($dependencies.dependencies | Where-Object criticality -notin @('startup-fatal','readiness-critical','capability-critical','optional','operational')).Count -eq 0
    backpressureThresholdsOrdered = ([TimeSpan]::Parse($backpressure.thresholds.warningAge) -lt [TimeSpan]::Parse($backpressure.thresholds.criticalAge)) -and
        ($backpressure.thresholds.warningCount -lt $backpressure.thresholds.criticalCount) -and
        ($backpressure.thresholds.warningConsecutiveFailures -lt $backpressure.thresholds.criticalConsecutiveFailures) -and
        ([TimeSpan]::Parse($backpressure.thresholds.warningSilence) -lt [TimeSpan]::Parse($backpressure.thresholds.criticalSilence))
    backpressureDimensionsComplete = @('moduleId','eventCategory','pendingCount','oldestPendingAge','retryCount','deadLetterCount','lastSucceeded','processingRatePerSecond','storageUtilization','expiredLeaseCount','duplicateRate','consecutiveFailures','dispatcherSilence' | Where-Object { $_ -notin $backpressure.requiredDimensions }).Count -eq 0
}
$report = [ordered]@{ formatVersion=1; gate='G04'; phase=1; result=if($checks.Values -contains $false){'failed'}else{'passed'}; checks=$checks; hashes=[ordered]@{releaseManifest=$second;moduleManifest=Sha 'deployment/g04/module-manifest.json';deploymentUnitCatalog=Sha 'deployment/g04/deployment-unit-catalog.json'} }
$resolved = Repo $ReportPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolved) | Out-Null
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolved -Encoding utf8NoBOM
if ($report.result -ne 'passed') { throw "G04 manifest validation failed: $resolved" }
Write-Host "G04 manifest validation passed: $resolved"
