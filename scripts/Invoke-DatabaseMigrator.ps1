[CmdletBinding()]
param(
    [ValidateSet("preflight", "dry-run", "apply", "validate")]
    [string] $Mode = "preflight",
    [string] $ReportPath = "artifacts/database-migrator/report.json",
    [switch] $ExplicitAuthAdoption,
    [switch] $NoBuild
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repositoryRoot "src/DatabaseMigrator/IFX.DatabaseMigrator/IFX.DatabaseMigrator.csproj"
$arguments = @("run", "--project", $project)
if ($NoBuild) {
    $arguments += "--no-build"
}
$arguments += @("--", "--mode", $Mode, "--report", $ReportPath)
if ($ExplicitAuthAdoption) {
    $arguments += "--explicit-auth-adoption"
}

dotnet @arguments
exit $LASTEXITCODE
