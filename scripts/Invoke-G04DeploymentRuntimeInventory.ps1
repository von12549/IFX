[CmdletBinding()]
param(
    [string] $ReportPath = 'docs/architecture/review/evidence/gates/G04/G04-runtime-inventory.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$resolvedReportPath = if ([System.IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $repositoryRoot $ReportPath }

$programPath = Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/Program.cs'
$healthPath = Join-Path $repositoryRoot 'src/ApiHost/IFX.ApiHost/Configuration/HealthCheckConfiguration.cs'
$backgroundJobsPath = Join-Path $repositoryRoot 'src/Platform/BackgroundJobs/IFX.Platform.BackgroundJobs.Composition/BackgroundJobsServiceCollectionExtensions.cs'
$composePath = Join-Path $repositoryRoot 'docker-compose.yml'
$nasComposePath = Join-Path $repositoryRoot 'docker-compose.nas.yml'

$program = Get-Content -Raw -LiteralPath $programPath
$health = Get-Content -Raw -LiteralPath $healthPath
$backgroundJobs = Get-Content -Raw -LiteralPath $backgroundJobsPath
$compose = Get-Content -Raw -LiteralPath $composePath
$nasCompose = Get-Content -Raw -LiteralPath $nasComposePath

$moduleCalls = [regex]::Matches($program, 'Add(Auth|Crm|Registry|Holdings|Transaction)Module') |
    ForEach-Object { $_.Groups[1].Value } |
    Select-Object -Unique

$report = [ordered]@{
    formatVersion = 1
    gate = 'G04'
    baseline = 'pre-implementation'
    sourceCommit = 'a663cc57947329e8a46efdbfe8aa6885348dd24b'
    deploymentUnits = @(
        [ordered]@{ id='ifx-api'; kind='web-process'; artifact='IFX.ApiHost'; lifecycle='business-release'; currentRole='all' }
        [ordered]@{ id='ifx-frontend'; kind='web-process'; artifact='IFX.FrontEnd'; lifecycle='independent'; currentRole='frontend' }
        [ordered]@{ id='ifx-database-migrator'; kind='one-shot'; artifact='IFX.DatabaseMigrator'; lifecycle='release-aligned-independent-execution'; currentRole='migrator' }
        [ordered]@{ id='sqlserver-init'; kind='one-shot'; artifact='mssql-tools'; lifecycle='infrastructure'; currentRole='bootstrap' }
        [ordered]@{ id='sqlserver'; kind='infrastructure'; artifact='mssql-server-2022'; lifecycle='independent'; currentRole='database' }
        [ordered]@{ id='opa'; kind='infrastructure'; artifact='opa-0.70.0'; lifecycle='independent'; currentRole='policy' }
        [ordered]@{ id='cognito'; kind='managed-dependency'; artifact='external'; lifecycle='provider-owned'; currentRole='identity' }
        [ordered]@{ id='sendgrid'; kind='managed-dependency'; artifact='external'; lifecycle='provider-owned'; currentRole='notifications' }
    )
    businessBoundary = [ordered]@{
        host = 'IFX.ApiHost'
        requiredModules = @($moduleCalls)
        lockstep = $true
        moduleCount = @($moduleCalls).Count
    }
    startup = [ordered]@{
        moduleRegistrationOrder = @($moduleCalls)
        platformRegistrationOrder = @('Messaging','BackgroundJobs','Notifications')
        endpointMapping = 'IModuleInstaller enumeration'
        migrationInApiStartup = $false
        independentMigratorComposeDependency = $compose -match 'ifx-database-migrator:[\s\S]*?ifx-api:[\s\S]*?depends_on:[\s\S]*?ifx-database-migrator:'
    }
    hostedRuntime = [ordered]@{
        hangfireServerImplicit = $backgroundJobs -match 'AddHangfireServer'
        hangfireClientServerSplit = $false
        customHostedServiceCount = 0
        outboxDispatcherPresent = $false
        consumerLoopPresent = $false
        recurringRegistrationAuthorityPresent = $false
    }
    probes = [ordered]@{
        paths = @('/health','/health/database','/health/ready')
        liveSeparated = $health -match '"/health/live"'
        startupSeparated = $health -match '"/health/startup"'
        detailsProtected = $false
        aggregateAndReadyEquivalent = ($health -match 'MapHealthChecks\("/health"[\s\S]*?Predicate = _ => true') -and ($health -match 'MapHealthChecks\("/health/ready"[\s\S]*?Predicate = _ => true')
        externalChecks = @('SQL Server','AWS Cognito')
        schemaCheck = 'Database schema compatibility'
    }
    orchestration = [ordered]@{
        composeFiles = @('docker-compose.yml','docker-compose.nas.yml')
        initBeforeMigrator = ($compose -match 'sqlserver-init:[\s\S]*?ifx-database-migrator:[\s\S]*?sqlserver-init:')
        migratorBeforeApi = $compose -match 'ifx-api:[\s\S]*?ifx-database-migrator:'
        explicitReplicaCount = $false
        stopSignalConfigured = ($compose -match 'stop_signal:') -or ($nasCompose -match 'stop_signal:')
        stopGraceConfigured = ($compose -match 'stop_grace_period:') -or ($nasCompose -match 'stop_grace_period:')
        uniqueRuntimeIdentity = $false
        fixedHangfireNameDefault = ($compose -match 'auth-api-worker') -or ($nasCompose -match 'auth-api-worker')
    }
    knownGaps = @(
        'No explicit api/worker/all runtime role'
        'Hangfire server scales implicitly with every API replica'
        'No dispatcher, consumer loop, lease, backlog or backpressure runtime exists yet'
        'No explicit drain coordinator or shutdown budget'
        'Liveness, startup, readiness and protected details are not separated'
        'No module or release manifest validates endpoint and required-module identity'
    )
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedReportPath) | Out-Null
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedReportPath -Encoding utf8NoBOM
Write-Host "G04 runtime inventory written: $resolvedReportPath"
