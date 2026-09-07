[CmdletBinding()]
param([string] $OutputPath = 'deployment/g04/release-runtime-manifest.json')

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
function Resolve-RepoPath([string] $path) { if ([IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $repositoryRoot $path } }
function Get-Sha([string] $path) { (Get-FileHash -Algorithm SHA256 -LiteralPath (Resolve-RepoPath $path)).Hash.ToLowerInvariant() }

$modulePath = 'deployment/g04/module-manifest.json'
$unitPath = 'deployment/g04/deployment-unit-catalog.json'
$compatibilityPath = 'deployment/g04/infrastructure-compatibility-matrix.json'
$schemaReleasePath = 'deployment/release-manifest.json'
$migrationPath = 'src/DatabaseMigrator/IFX.DatabaseMigrator/migration-manifest.json'
$hostProjectPath = 'src/ApiHost/IFX.ApiHost/IFX.ApiHost.csproj'
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
    }
    schemaCompatibility = [ordered]@{ policy='expand-contract'; cleanupRequires='observed-zero-old-version-demand' }
}
$resolvedOutputPath = Resolve-RepoPath $OutputPath
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutputPath) | Out-Null
$manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedOutputPath -Encoding utf8NoBOM
Write-Host "G04 release manifest generated: $resolvedOutputPath"
