# Relocated from docs/guards/V3_ifx/stages/post/gates/specialized/scripts/New-DatabaseMigrationArtifacts.ps1 (IFX I2-B amendment A2, rulings R6-R10). Adapted: GUARD_TARGET_ROOT only (set by Invoke-IFXSpecialized.ps1).
[CmdletBinding()]
param(
    [string] $OutputDirectory = "artifacts/database-migrator/release",
    [string] $ReleaseManifest = "deployment/release-manifest.json",
    [ValidateSet("Debug", "Release")]
    [string] $Configuration = "Release",
    [switch] $NoBuild
)

$ErrorActionPreference = "Stop"
$repositoryRoot = if ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { throw 'An explicit Target root is required: the relocated producers never derive the repository from their own location.' }
$project = Join-Path $repositoryRoot "src/DatabaseMigrator/IFX.DatabaseMigrator/IFX.DatabaseMigrator.csproj"
$arguments = @("run", "--project", $project, "--configuration", $Configuration)
if ($NoBuild) {
    $arguments += "--no-build"
}
$arguments += @(
    "--",
    "--mode", "scripts",
    "--artifact-dir", $(if ([IO.Path]::IsPathRooted($OutputDirectory)) { $OutputDirectory } else { Join-Path $repositoryRoot $OutputDirectory }),
    "--release-manifest", $(if ([IO.Path]::IsPathRooted($ReleaseManifest)) { $ReleaseManifest } else { Join-Path $repositoryRoot $ReleaseManifest })
)

dotnet @arguments
if ($LASTEXITCODE -ne 0) { throw "Database migration artifact generation failed with exit code $LASTEXITCODE." }
