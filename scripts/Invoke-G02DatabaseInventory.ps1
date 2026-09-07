param(
    [string] $ReportPath = "docs/architecture/review/evidence/gates/G02/G02-database-inventory.json",
    [string] $ManifestPath = "docs/architecture/review/evidence/gates/G02/G02-migration-manifest.json",
    [switch] $NoBuild
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repositoryRoot "tools/IFX.DatabaseInventory/IFX.DatabaseInventory.csproj"
$arguments = @("run", "--project", $project)
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
