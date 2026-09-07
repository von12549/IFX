param(
    [string] $ReportPath = "docs/architecture/review/evidence/gates/G02/G02-phase0-guard-report.json",
    [ValidateRange(0, 10)]
    [int] $Phase = 0,
    [switch] $NoBuild
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$inventoryPath = Join-Path $repositoryRoot "docs/architecture/review/evidence/gates/G02/G02-database-inventory.json"
$manifestPath = Join-Path $repositoryRoot "docs/architecture/review/evidence/gates/G02/G02-migration-manifest.json"
$generator = Join-Path $PSScriptRoot "Invoke-G02DatabaseInventory.ps1"
$resolvedReportPath = Join-Path $repositoryRoot $ReportPath

function Invoke-InventoryGenerator {
    $parameters = @{
        ReportPath = $inventoryPath
        ManifestPath = $manifestPath
    }
    if ($NoBuild) {
        $parameters.NoBuild = $true
    }

    & $generator @parameters
    if ($LASTEXITCODE -ne 0) {
        throw "G02 database inventory generator failed with exit code $LASTEXITCODE."
    }
}

Invoke-InventoryGenerator
$firstInventoryHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryPath).Hash.ToLowerInvariant()
$firstManifestHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $manifestPath).Hash.ToLowerInvariant()

Invoke-InventoryGenerator
$secondInventoryHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $inventoryPath).Hash.ToLowerInvariant()
$secondManifestHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $manifestPath).Hash.ToLowerInvariant()

$inventory = Get-Content -Raw -LiteralPath $inventoryPath | ConvertFrom-Json -Depth 100
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json -Depth 100
$migrationIds = @($manifest.modules.migrations.MigrationId)
$duplicates = @($migrationIds | Group-Object | Where-Object Count -gt 1 | Select-Object -ExpandProperty Name)
$schemaViolations = @(
    @($inventory.modules.SchemaViolations) + @($inventory.staticScan.CrossSchemaFindings) |
        Where-Object { $null -ne $_ }
)
$expectedModules = @("Auth", "CRM", "Registry", "Holdings", "Transaction")
$actualModules = @($manifest.modules.module)
$missingModules = @($expectedModules | Where-Object { $_ -notin $actualModules })
$unexpectedModules = @($actualModules | Where-Object { $_ -notin $expectedModules })

$secretPatterns = @(
    '(?i)password\s*=',
    '(?i)user\s+id\s*=',
    '(?i)accountkey\s*=',
    '(?i)(client|tenant)[_-]?secret\s*[:=]'
)
$secretFindings = @()
foreach ($path in @($inventoryPath, $manifestPath)) {
    $content = Get-Content -Raw -LiteralPath $path
    foreach ($pattern in $secretPatterns) {
        if ($content -match $pattern) {
            $secretFindings += [pscustomobject]@{
                file = [System.IO.Path]::GetRelativePath($repositoryRoot, $path).Replace('\', '/')
                pattern = $pattern
            }
        }
    }
}

$checks = [ordered]@{
    deterministicInventory = $firstInventoryHash -eq $secondInventoryHash
    deterministicManifest = $firstManifestHash -eq $secondManifestHash
    exactModuleSet = $missingModules.Count -eq 0 -and $unexpectedModules.Count -eq 0 -and $actualModules.Count -eq 5
    everyModuleHasMigrations = @($manifest.modules | Where-Object { $_.migrations.Count -eq 0 }).Count -eq 0
    uniqueMigrationIds = $duplicates.Count -eq 0
    schemaOwnership = $schemaViolations.Count -eq 0
    generatedEvidenceContainsNoSecrets = $secretFindings.Count -eq 0
}

$report = [ordered]@{
    formatVersion = 1
    gate = "G02"
    phase = $Phase
    result = if ($checks.Values -contains $false) { "failed" } else { "passed" }
    checks = $checks
    counts = [ordered]@{
        modules = $actualModules.Count
        entityTypes = @($inventory.modules.Entities).Count
        uniqueTables = @($inventory.modules.Entities | ForEach-Object { "$($_.Schema).$($_.Table)" } | Sort-Object -Unique).Count
        keys = @($inventory.modules.Entities.Keys | Where-Object { $null -ne $_ }).Count
        foreignKeys = @($inventory.modules.Entities.ForeignKeys | Where-Object { $null -ne $_ }).Count
        checkConstraints = @($inventory.modules.Entities.CheckConstraints | Where-Object { $null -ne $_ }).Count
        migrations = $migrationIds.Count
        rawSqlFindings = @($inventory.staticScan.RawSqlFindings).Count
        schemaQualifiedTableReferences = @($inventory.staticScan.SchemaQualifiedTableReferences).Count
        crossSchemaFindings = $schemaViolations.Count
        secretFindings = $secretFindings.Count
    }
    sha256 = [ordered]@{
        inventory = $secondInventoryHash
        manifest = $secondManifestHash
    }
    failures = [ordered]@{
        missingModules = $missingModules
        unexpectedModules = $unexpectedModules
        duplicateMigrationIds = $duplicates
        schemaViolations = $schemaViolations
        secretFindings = $secretFindings
    }
}

$reportDirectory = Split-Path -Parent $resolvedReportPath
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$report | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $resolvedReportPath -Encoding utf8NoBOM

if ($report.result -ne "passed") {
    throw "G02 Phase $Phase guard failed. Report: $resolvedReportPath"
}

Write-Host "G02 Phase $Phase guard passed. Report: $resolvedReportPath"
