# Relocated from docs/guards/V3_ifx/stages/post/gates/specialized/scripts/Invoke-G02DatabaseInventory.ps1 (IFX I2-B amendment A2, rulings R6-R10). Adapted: GUARD_TARGET_ROOT only (set by Invoke-IFXSpecialized.ps1).
param(
    [string] $ReportPath = "docs/architecture/review/evidence/gates/G02/G02-database-inventory.json",
    [string] $ManifestPath = "docs/architecture/review/evidence/gates/G02/G02-migration-manifest.json",
    [switch] $NoBuild,
    [ValidateSet('Debug','Release')][string] $Configuration = 'Debug'
)

$ErrorActionPreference = "Stop"
$repositoryRoot = if ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { throw 'An explicit Target root is required: the relocated producers never derive the repository from their own location.' }
$project = Join-Path $repositoryRoot "tools/IFX.DatabaseInventory/IFX.DatabaseInventory.csproj"
$arguments = @("run", "--project", $project, "--configuration", $Configuration)
if ($NoBuild) {
    $arguments += "--no-build"
}
$arguments += @(
    "--",
    "--root", $repositoryRoot,
    "--output", $ReportPath,
    "--manifest-output", $ManifestPath)

dotnet @arguments
if ($LASTEXITCODE -ne 0) {
    throw "G02 database inventory failed with exit code $LASTEXITCODE."
}
