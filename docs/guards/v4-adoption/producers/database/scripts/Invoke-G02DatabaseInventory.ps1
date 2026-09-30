param(
    [string] $ReportPath = "docs/architecture/review/evidence/gates/G02/G02-database-inventory.json",
    [string] $ManifestPath = "docs/architecture/review/evidence/gates/G02/G02-migration-manifest.json",
    [switch] $NoBuild,
    [ValidateSet('Debug','Release')][string] $Configuration = 'Debug'
)

$ErrorActionPreference = "Stop"
$repositoryRoot = if ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../../../../..')) }
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
