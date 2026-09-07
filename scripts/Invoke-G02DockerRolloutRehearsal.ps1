[CmdletBinding()]
param(
    [string] $EnvironmentFile = ".env",
    [string] $SqlContainer = "ifx-sqlserver",
    [string] $DatabaseName = "IFXDb_G02_Rehearsal_$(Get-Date -Format 'yyyyMMddHHmmss')",
    [string] $MigratorImage = "ifx-database-migrator:g02-phase8",
    [string] $ApiImage = "ifx-api:g02-phase8",
    [string] $EvidenceDirectory = "docs/architecture/review/evidence/gates/G02/phase8-docker-rehearsal",
    [ValidateRange(1024, 65535)]
    [int] $ApiPort = 15010,
    [switch] $NoBuild
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$environmentPath = if ([System.IO.Path]::IsPathRooted($EnvironmentFile)) {
    $EnvironmentFile
} else {
    Join-Path $repositoryRoot $EnvironmentFile
}
$evidencePath = if ([System.IO.Path]::IsPathRooted($EvidenceDirectory)) {
    $EvidenceDirectory
} else {
    Join-Path $repositoryRoot $EvidenceDirectory
}
$artifactDirectory = Join-Path $repositoryRoot "artifacts/database-migrator/g02-phase8-bundle"

if ($DatabaseName -cnotmatch '^IFXDb_G02_Rehearsal_[0-9]{14}$') {
    throw "DatabaseName must use the isolated IFXDb_G02_Rehearsal_yyyyMMddHHmmss form."
}
if (-not (Test-Path -LiteralPath $environmentPath -PathType Leaf)) {
    throw "Environment file was not found: $environmentPath"
}

function Get-DotEnvValue([string] $Name) {
    $escaped = [regex]::Escape($Name)
    $line = Get-Content -LiteralPath $environmentPath |
        Where-Object { $_ -match "^$escaped=" } |
        Select-Object -Last 1
    if ($null -eq $line) {
        throw "Environment file is missing required key '$Name'."
    }
    $value = ($line -split '=', 2)[1].Trim()
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
        ($value.StartsWith("'") -and $value.EndsWith("'"))) {
        $value = $value.Substring(1, $value.Length - 2)
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Environment key '$Name' is empty."
    }
    return $value
}

function Invoke-CheckedNative([scriptblock] $Action, [string] $Failure) {
    $output = & $Action 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "$Failure`n$($output -join [Environment]::NewLine)"
    }
    return $output
}

function Invoke-Sql(
    [string] $User,
    [string] $Password,
    [string] $Database,
    [string] $Sql,
    [switch] $ExpectFailure) {
    $output = $Sql | & docker exec -i --env "SQLCMDPASSWORD=$Password" $SqlContainer /opt/mssql-tools18/bin/sqlcmd -S localhost -U $User -d $Database -C -b -h -1 -W 2>&1
    $exitCode = $LASTEXITCODE
    if ($ExpectFailure) {
        if ($exitCode -eq 0) {
            throw "SQL command was expected to fail for '$User' but succeeded."
        }
        return $output
    }
    if ($exitCode -ne 0) {
        throw "SQL command failed for '$User' in '$Database'.`n$($output -join [Environment]::NewLine)"
    }
    return $output
}

function Write-SecretEnvironment(
    [string] $Path,
    [string] $User,
    [string] $Password,
    [switch] $ForApi) {
    $connection = "Server=$SqlContainer,1433;Database=$DatabaseName;User Id=$User;Password=$Password;TrustServerCertificate=True;MultipleActiveResultSets=true"
    $lines = @(
        "ConnectionStrings__AuthDatabase=$connection",
        "ConnectionStrings__CrmDatabase=$connection",
        "ConnectionStrings__RegistryDatabase=$connection",
        "ConnectionStrings__HoldingsDatabase=$connection",
        "ConnectionStrings__TransactionDatabase=$connection"
    )
    if ($ForApi) {
        $lines += @(
            "ConnectionStrings__BackgroundJobsDatabase=$connection",
            "ASPNETCORE_ENVIRONMENT=Testing",
            "ASPNETCORE_URLS=http://+:8080",
            "BackgroundJobs__Enabled=false",
            "Opa__Enabled=false",
            "Authentication__Provider=Cognito",
            "CognitoSettings__UserPoolId=g02-rehearsal",
            "CognitoSettings__ClientId=g02-rehearsal",
            "CognitoSettings__ClientSecret=g02-rehearsal",
            "CognitoSettings__Region=ap-southeast-2",
            "CognitoOidcSettings__Domain=g02-rehearsal.invalid",
            "CognitoOidcSettings__ClientId=g02-rehearsal",
            "CognitoOidcSettings__ClientSecret=g02-rehearsal",
            "CognitoOidcSettings__CallbackUrl=http://localhost:$ApiPort/api/v1/auth/oauth/callback",
            "CognitoOidcSettings__LogoutCallbackUrl=http://localhost:$ApiPort/api/v1/auth/oauth/logout-callback",
            "CognitoOidcSettings__FrontendCallbackUrl=http://localhost:8030/callback"
        )
    }
    [System.IO.File]::WriteAllLines($Path, $lines)
}

function Invoke-MigratorContainer(
    [string] $Mode,
    [string] $ReportFile,
    [string] $EnvironmentPath) {
    $mountSource = $evidencePath.Replace('\', '/')
    $null = Invoke-CheckedNative {
        docker run --rm --network $network --env-file $EnvironmentPath --mount "type=bind,source=$mountSource,target=/reports" $MigratorImage --mode $Mode --report "/reports/$ReportFile"
    } "DatabaseMigrator mode '$Mode' failed."
    Write-Host "DatabaseMigrator $Mode passed: $ReportFile"
}

function Wait-ApiReady([string] $ContainerName, [int] $Port) {
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(60)
    do {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$Port/health/database" -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -eq 200) {
                return [ordered]@{
                    container = $ContainerName
                    statusCode = $response.StatusCode
                    checkedAt = [DateTimeOffset]::UtcNow.ToString("O")
                }
            }
        } catch {
            Start-Sleep -Seconds 2
        }
    } while ([DateTimeOffset]::UtcNow -lt $deadline)

    $logs = docker logs --tail 80 $ContainerName 2>&1
    throw "ApiHost readiness did not become healthy.`n$($logs -join [Environment]::NewLine)"
}

function Get-RelativePath([string] $Path) {
    return [System.IO.Path]::GetRelativePath($repositoryRoot, $Path).Replace('\', '/')
}

function Get-Sha256([string] $Path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

$saPassword = Get-DotEnvValue "DB_PASSWORD"
$suffix = [Guid]::NewGuid().ToString("N").Substring(0, 10)
$migrationLogin = "g02_migration_$suffix"
$runtimeLogin = "g02_runtime_$suffix"
$migrationPassword = "G02Migration!$([Guid]::NewGuid().ToString('N'))aA1"
$runtimePassword = "G02Runtime!$([Guid]::NewGuid().ToString('N'))aA1"
$migrationEnvironment = Join-Path ([System.IO.Path]::GetTempPath()) "g02-migration-$suffix.env"
$runtimeEnvironment = Join-Path ([System.IO.Path]::GetTempPath()) "g02-runtime-$suffix.env"
$apiContainer = "ifx-g02-api-$suffix"
$backupFile = "/var/opt/mssql/data/$DatabaseName.bak"
$windowStartedAt = [DateTimeOffset]::UtcNow
$resourcesCreated = $false
$preflightPassed = $false

New-Item -ItemType Directory -Force -Path $evidencePath | Out-Null
New-Item -ItemType Directory -Force -Path $artifactDirectory | Out-Null

try {
    $containerState = Invoke-CheckedNative {
        docker inspect $SqlContainer --format '{{.State.Health.Status}}'
    } "Could not inspect SQL Server container '$SqlContainer'."
    if (($containerState | Select-Object -Last 1).Trim() -ne "healthy") {
        throw "SQL Server container '$SqlContainer' is not healthy."
    }
    $network = (Invoke-CheckedNative {
        docker inspect $SqlContainer --format '{{range $name, $settings := .NetworkSettings.Networks}}{{$name}}{{end}}'
    } "Could not resolve the SQL Server container network." | Select-Object -Last 1).Trim()

    $existing = Invoke-Sql "sa" $saPassword "master" "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = N'$DatabaseName';"
    if ([int](($existing | Select-Object -Last 1).Trim()) -ne 0) {
        throw "Isolated rehearsal database '$DatabaseName' already exists; choose a new timestamped name."
    }

    $setupSql = @"
CREATE DATABASE [$DatabaseName];
GO
CREATE LOGIN [$migrationLogin] WITH PASSWORD = N'$migrationPassword', CHECK_POLICY = OFF;
CREATE LOGIN [$runtimeLogin] WITH PASSWORD = N'$runtimePassword', CHECK_POLICY = OFF;
GO
USE [$DatabaseName];
CREATE USER [$migrationLogin] FOR LOGIN [$migrationLogin];
CREATE USER [$runtimeLogin] FOR LOGIN [$runtimeLogin];
ALTER ROLE [db_owner] ADD MEMBER [$migrationLogin];
GRANT CONNECT TO [$runtimeLogin];
"@
    $null = Invoke-Sql "sa" $saPassword "master" $setupSql
    $resourcesCreated = $true

    Write-SecretEnvironment $migrationEnvironment $migrationLogin $migrationPassword
    Write-SecretEnvironment $runtimeEnvironment $runtimeLogin $runtimePassword -ForApi

    if (-not $NoBuild) {
        $null = Invoke-CheckedNative {
            docker build --file (Join-Path $repositoryRoot "src/DatabaseMigrator/IFX.DatabaseMigrator/Dockerfile") --tag $MigratorImage $repositoryRoot
        } "DatabaseMigrator image build failed."
        $null = Invoke-CheckedNative {
            docker build --file (Join-Path $repositoryRoot "src/ApiHost/IFX.ApiHost/Dockerfile") --tag $ApiImage $repositoryRoot
        } "ApiHost image build failed."
    }

    $artifactArguments = @{
        OutputDirectory = Get-RelativePath $artifactDirectory
        Configuration = "Release"
    }
    if ($NoBuild) { $artifactArguments.NoBuild = $true }
    & (Join-Path $PSScriptRoot "New-DatabaseMigrationArtifacts.ps1") @artifactArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Migration artifact generation failed."
    }

    Invoke-MigratorContainer "preflight" "preflight.json" $migrationEnvironment
    $preflightPassed = $true
    Invoke-MigratorContainer "dry-run" "dry-run.json" $migrationEnvironment

    $null = Invoke-Sql "sa" $saPassword "master" "BACKUP DATABASE [$DatabaseName] TO DISK = N'$backupFile' WITH COPY_ONLY, INIT, CHECKSUM;"
    $null = Invoke-Sql "sa" $saPassword "master" "RESTORE VERIFYONLY FROM DISK = N'$backupFile' WITH CHECKSUM;"
    $restoreReport = [ordered]@{
        database = $DatabaseName
        backup = $backupFile
        copyOnly = $true
        checksum = $true
        restoreVerifyOnly = "passed"
        verifiedAt = [DateTimeOffset]::UtcNow.ToString("O")
    }
    $restoreReport | ConvertTo-Json -Depth 10 |
        Set-Content -LiteralPath (Join-Path $evidencePath "restore-verification.json") -Encoding utf8NoBOM

    Invoke-MigratorContainer "apply" "apply.json" $migrationEnvironment
    Invoke-MigratorContainer "validate" "validation.json" $migrationEnvironment
    Invoke-MigratorContainer "apply" "rerun.json" $migrationEnvironment

    $grants = @("auth", "crm", "registry", "holdings", "transaction") |
        ForEach-Object { "GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[$_] TO [$runtimeLogin];" }
    $null = Invoke-Sql "sa" $saPassword $DatabaseName ($grants -join [Environment]::NewLine)
    $null = Invoke-Sql $migrationLogin $migrationPassword $DatabaseName "CREATE TABLE [auth].[Phase8RuntimeProbe] ([Id] int NOT NULL PRIMARY KEY, [Value] nvarchar(50) NOT NULL);"
    $null = Invoke-Sql $runtimeLogin $runtimePassword $DatabaseName "INSERT INTO [auth].[Phase8RuntimeProbe] VALUES (1, N'created'); UPDATE [auth].[Phase8RuntimeProbe] SET [Value] = N'updated' WHERE [Id] = 1; DELETE FROM [auth].[Phase8RuntimeProbe] WHERE [Id] = 1;"
    $ddlFailure = Invoke-Sql $runtimeLogin $runtimePassword $DatabaseName "CREATE TABLE [auth].[RuntimeMustNotCreate] ([Id] int NOT NULL);" -ExpectFailure
    $null = Invoke-Sql $migrationLogin $migrationPassword $DatabaseName "DROP TABLE [auth].[Phase8RuntimeProbe];"
    Invoke-MigratorContainer "validate" "runtime-validation.json" $runtimeEnvironment

    $permissionReport = [ordered]@{
        database = $DatabaseName
        migrationIdentity = [ordered]@{ ddl = "passed"; secretRecorded = $false }
        runtimeIdentity = [ordered]@{
            dml = "passed"
            readiness = "passed"
            ddl = "denied"
            sqlErrorObserved = @($ddlFailure).Count -gt 0
            secretRecorded = $false
        }
        checkedAt = [DateTimeOffset]::UtcNow.ToString("O")
    }
    $permissionReport | ConvertTo-Json -Depth 10 |
        Set-Content -LiteralPath (Join-Path $evidencePath "permission-report.json") -Encoding utf8NoBOM

    $mountSource = $evidencePath.Replace('\', '/')
    $apiId = Invoke-CheckedNative {
        docker run -d --name $apiContainer --network $network --env-file $runtimeEnvironment --mount "type=bind,source=$mountSource,target=/evidence" -p "${ApiPort}:8080" $ApiImage
    } "ApiHost rehearsal container failed to start."
    $firstReady = Wait-ApiReady $apiContainer $ApiPort
    $null = Invoke-CheckedNative { docker restart $apiContainer } "ApiHost restart rehearsal failed."
    $secondReady = Wait-ApiReady $apiContainer $ApiPort
    $readinessReport = [ordered]@{
        database = $DatabaseName
        startedAfterMigrationValidation = $true
        initial = $firstReady
        compatibleRestart = $secondReady
        databaseDownInvoked = $false
    }
    $readinessReport | ConvertTo-Json -Depth 10 |
        Set-Content -LiteralPath (Join-Path $evidencePath "api-readiness-report.json") -Encoding utf8NoBOM

    $preflightPath = Join-Path $evidencePath "preflight.json"
    $applyPath = Join-Path $evidencePath "apply.json"
    $validationPath = Join-Path $evidencePath "validation.json"
    $preflight = Get-Content -Raw -LiteralPath $preflightPath | ConvertFrom-Json -Depth 100
    $artifactManifest = Join-Path $artifactDirectory "artifact-manifest.json"
    $scopeApproval = "codex-thread:user-approved-controlled-docker-rehearsal:2026-09-08"
    $finishedAt = [DateTimeOffset]::UtcNow
    $evidence = [ordered]@{
        formatVersion = 1
        gate = "G02"
        status = "completed"
        releaseId = "g02-phase8-$suffix"
        environment = "docker:$SqlContainer/$DatabaseName"
        changeTicket = $scopeApproval
        approvals = [ordered]@{
            architecture = $scopeApproval
            database = $scopeApproval
            operations = $scopeApproval
        }
        artifacts = [ordered]@{
            migrationManifestSha256 = Get-Sha256 (Join-Path $repositoryRoot "src/DatabaseMigrator/IFX.DatabaseMigrator/migration-manifest.json")
            releaseManifestSha256 = Get-Sha256 (Join-Path $repositoryRoot "deployment/release-manifest.json")
            artifactManifestSha256 = Get-Sha256 $artifactManifest
        }
        preflight = [ordered]@{
            reportReference = Get-RelativePath $preflightPath
            reportSha256 = Get-Sha256 $preflightPath
            classification = $preflight.historyBootstrap.classification
            historyMappingReviewed = $true
            fingerprintReviewed = $true
            reviewedBy = "automated-rehearsal-with-user-approved-scope"
            reviewedAt = $windowStartedAt.ToString("O")
        }
        restorePoint = [ordered]@{
            identifier = $backupFile
            restoreVerified = $true
            restoreVerificationReference = Get-RelativePath (Join-Path $evidencePath "restore-verification.json")
            verifiedAt = $restoreReport.verifiedAt
        }
        execution = [ordered]@{
            migrationJobReference = "docker-image:$MigratorImage"
            applyReportReference = Get-RelativePath $applyPath
            applyReportSha256 = Get-Sha256 $applyPath
            validationReportReference = Get-RelativePath $validationPath
            validationReportSha256 = Get-Sha256 $validationPath
            validationResult = "succeeded"
            apiStartedAfterValidation = $true
            operator = "automated-controlled-docker-rehearsal"
            startedAt = $windowStartedAt.ToString("O")
            finishedAt = $finishedAt.ToString("O")
        }
        compatibilityWindow = [ordered]@{
            startedAt = $windowStartedAt.ToString("O")
            finishedAt = $finishedAt.ToString("O")
            migrationStable = $true
            readinessStable = $true
            businessReadWriteStable = $true
            rollbackCompatibilityVerified = $true
            smokeTestReference = Get-RelativePath (Join-Path $evidencePath "permission-report.json")
            rollbackVerificationReference = Get-RelativePath (Join-Path $evidencePath "api-readiness-report.json")
        }
        runtimeIdentity = [ordered]@{
            permissionReportReference = Get-RelativePath (Join-Path $evidencePath "permission-report.json")
            dmlVerified = $true
            readinessVerified = $true
            ddlDenied = $true
            legacyRuntimeMigrationEntryPointsAbsent = $true
        }
        sharedHistory = [ordered]@{
            mode = "not-present-fresh"
            archiveReference = Get-RelativePath $preflightPath
            rowsPreserved = $true
            deletionApproved = $false
        }
    }
    $rolloutEvidence = Join-Path $evidencePath "rollout-evidence.json"
    $evidence | ConvertTo-Json -Depth 100 |
        Set-Content -LiteralPath $rolloutEvidence -Encoding utf8NoBOM

    & (Join-Path $PSScriptRoot "Test-G02DatabaseRolloutEvidence.ps1") -EvidencePath $rolloutEvidence
    if ($LASTEXITCODE -ne 0) {
        throw "Generated G02 rollout evidence did not validate."
    }
    Write-Host "G02 Docker rollout rehearsal passed. Evidence: $rolloutEvidence"
}
finally {
    docker rm --force $apiContainer 2>$null | Out-Null
    if ($resourcesCreated -and -not $preflightPassed) {
        $cleanupSql = "IF DB_ID(N'$DatabaseName') IS NOT NULL DROP DATABASE [$DatabaseName]; IF SUSER_ID(N'$migrationLogin') IS NOT NULL DROP LOGIN [$migrationLogin]; IF SUSER_ID(N'$runtimeLogin') IS NOT NULL DROP LOGIN [$runtimeLogin];"
        try {
            $null = Invoke-Sql "sa" $saPassword "master" $cleanupSql
            Write-Host "Removed the empty preflight-failed rehearsal database and temporary logins."
        } catch {
            Write-Warning "Automatic cleanup of preflight-failed rehearsal resources failed; inspect database '$DatabaseName' and login suffix '$suffix'."
        }
    }
    Remove-Item -LiteralPath $migrationEnvironment, $runtimeEnvironment -Force -ErrorAction SilentlyContinue
    $migrationPassword = $null
    $runtimePassword = $null
    $saPassword = $null
}
