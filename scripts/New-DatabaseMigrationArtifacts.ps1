[CmdletBinding()]
param(
    [string] $OutputDirectory = "artifacts/database-migrator/release",
    [string] $ReleaseManifest = "deployment/release-manifest.json",
    [ValidateSet("Debug", "Release")]
    [string] $Configuration = "Release",
    [switch] $NoBuild
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repositoryRoot "src/DatabaseMigrator/IFX.DatabaseMigrator/IFX.DatabaseMigrator.csproj"
$arguments = @("run", "--project", $project, "--configuration", $Configuration)
if ($NoBuild) {
    $arguments += "--no-build"
}
$arguments += @(
    "--",
    "--mode", "scripts",
    "--artifact-dir", (Join-Path $repositoryRoot $OutputDirectory),
    "--release-manifest", (Join-Path $repositoryRoot $ReleaseManifest)
)

dotnet @arguments
exit $LASTEXITCODE
