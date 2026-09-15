[CmdletBinding()]
param([string] $OutputPath = 'deployment/g04/release-runtime-manifest.json')

$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
function Resolve-RepoPath([string] $path) { if ([IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $repositoryRoot $path } }
function Get-Sha([string] $path) {
    $resolved = Resolve-RepoPath $path
    $text = [IO.File]::ReadAllText($resolved).Replace("`r`n", "`n").Replace("`r", "`n")
    $bytes = [Text.Encoding]::UTF8.GetBytes($text)
    ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))).ToLowerInvariant()
}

$modulePath = 'deployment/g04/module-manifest.json'
$unitPath = 'deployment/g04/deployment-unit-catalog.json'
$compatibilityPath = 'deployment/g04/infrastructure-compatibility-matrix.json'
$schemaReleasePath = 'deployment/release-manifest.json'
$migrationPath = 'src/DatabaseMigrator/IFX.DatabaseMigrator/migration-manifest.json'
$hostProjectPath = 'src/ApiHost/IFX.ApiHost/IFX.ApiHost.csproj'
$orchestrationPath = 'deployment/g04/release-orchestration.json'
$backpressurePath = 'deployment/g04/backpressure-policy.json'
$failureMatrixPath = 'deployment/g04/failure-matrix.json'
$moduleManifest = Get-Content -Raw -LiteralPath (Resolve-RepoPath $modulePath) | ConvertFrom-Json -Depth 100

$manifest = [ordered]@{
    formatVersion = 1
    releaseId = $moduleManifest.releaseVersion
    businessBoundary = 'ifx-backend'
    hostArtifact = [ordered]@{
        artifactId = 'ifx-host'
        digest = "sha256:$(Get-Sha $hostProjectPath)"
        allowedRoles = @('api','worker','all')
    }
    requiredModuleIds = @($moduleManifest.modules | ForEach-Object { $_.moduleId })
    bindings = [ordered]@{
        moduleManifest = [ordered]@{ path=$modulePath; sha256=Get-Sha $modulePath }
        deploymentUnitCatalog = [ordered]@{ path=$unitPath; sha256=Get-Sha $unitPath }
        infrastructureCompatibility = [ordered]@{ path=$compatibilityPath; sha256=Get-Sha $compatibilityPath }
        schemaReleaseManifest = [ordered]@{ path=$schemaReleasePath; sha256=Get-Sha $schemaReleasePath }
        migrationManifest = [ordered]@{ path=$migrationPath; sha256=Get-Sha $migrationPath }
        releaseOrchestration = [ordered]@{ path=$orchestrationPath; sha256=Get-Sha $orchestrationPath }
        backpressurePolicy = [ordered]@{ path=$backpressurePath; sha256=Get-Sha $backpressurePath }
        failureMatrix = [ordered]@{ path=$failureMatrixPath; sha256=Get-Sha $failureMatrixPath }
    }
    schemaCompatibility = [ordered]@{ policy='expand-contract'; cleanupRequires='observed-zero-old-version-demand' }
}
$resolvedOutputPath = Resolve-RepoPath $OutputPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutputPath) | Out-Null
[IO.File]::WriteAllText($resolvedOutputPath, ($manifest | ConvertTo-Json -Depth 20).Replace("`r`n", "`n") + "`n", [Text.UTF8Encoding]::new($false))
Write-Host "G04 release manifest generated: $resolvedOutputPath"
