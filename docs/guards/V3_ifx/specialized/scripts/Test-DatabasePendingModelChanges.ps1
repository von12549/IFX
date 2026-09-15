param(
    [switch] $NoBuild,
    [ValidateSet('Debug','Release')][string] $Configuration = 'Debug'
)

$ErrorActionPreference = "Stop"
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
$startupProject = Join-Path $repositoryRoot "src/ApiHost/IFX.ApiHost/IFX.ApiHost.csproj"
$contexts = @(
    @{ Name = "Auth"; Context = "IfxDbContext"; Project = "src/Modules/IAM/IFX.Modules.IAM.Infrastructure/IFX.Modules.IAM.Infrastructure.csproj" },
    @{ Name = "CRM"; Context = "CrmDbContext"; Project = "src/Modules/CRM/IFX.Modules.CRM.Infrastructure/IFX.Modules.CRM.Infrastructure.csproj" },
    @{ Name = "Registry"; Context = "RegistryDbContext"; Project = "src/Modules/Registry/IFX.Modules.Registry.Infrastructure/IFX.Modules.Registry.Infrastructure.csproj" },
    @{ Name = "Holdings"; Context = "HoldingsDbContext"; Project = "src/Modules/Holdings/IFX.Modules.Holdings.Infrastructure/IFX.Modules.Holdings.Infrastructure.csproj" },
    @{ Name = "Transaction"; Context = "TransactionDbContext"; Project = "src/Modules/Transaction/IFX.Modules.Transaction.Infrastructure/IFX.Modules.Transaction.Infrastructure.csproj" }
)

Push-Location $repositoryRoot
try {
    foreach ($entry in $contexts) {
        $arguments = @(
            "ef",
            "migrations",
            "has-pending-model-changes",
            "--project", (Join-Path $repositoryRoot $entry.Project),
            "--startup-project", $startupProject,
            "--context", $entry.Context
            "--configuration", $Configuration
        )
        if ($NoBuild) {
            $arguments += "--no-build"
        }
        $arguments += @("--", "--environment", "Testing")

        & dotnet @arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Pending-model check failed for $($entry.Name) with exit code $LASTEXITCODE."
        }
    }
}
finally {
    Pop-Location
}

Write-Host "All five module DbContexts match their latest model snapshots."
