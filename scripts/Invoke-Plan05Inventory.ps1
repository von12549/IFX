[CmdletBinding()]
param(
    [string] $OutputPath = 'docs/architecture/review/evidence/plan05/phase0-inventory.json',
    [string] $BaselineCommit = 'f29ad32'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repositoryRoot
try {
    $commit = (& git rev-parse "$BaselineCommit^{commit}").Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve inventory baseline.' }
    $paths = @(& git ls-tree -r --name-only $commit -- src tests deployment/g04 docs/architecture/review/gates/G03)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate baseline.' }
    $sourcePaths = @($paths | Where-Object {
        $_ -match '^src/(Modules/Auth/|ApiHost/IFX.ApiHost/(Authentication|Authorization|Configuration/Authentication)|BuildingBlocks/IFX.BuildingBlocks.Security/)' -and
        $_ -match '\.(cs|csproj)$'
    } | Sort-Object)
    $sources = foreach ($path in $sourcePaths) {
        $blob = (& git rev-parse "${commit}:$path").Trim()
        if ($LASTEXITCODE -ne 0) { throw "Cannot resolve $path" }
        $content = (& git show "${commit}:$path") -join "`n"
        if ($LASTEXITCODE -ne 0) { throw "Cannot read $path" }
        $owner = switch -Regex ($path) {
            '/IdentityProviders/' { 'Platform.Authentication'; break }
            '/(Authentication/|Configuration/Authentication)' { 'Authentication host adapter'; break }
            '/(Tenants|Departments)/|/(Tenant|Department|ITenantRepository|IDepartmentRepository)\.cs$' { 'IAM.Tenancy'; break }
            '/Identity/' { 'IAM.Identity'; break }
            '/Users/' { 'IAM.Users (assignment operations move to Access)'; break }
            '/BuildingBlocks/.*/Authorization/' { 'Review: Platform evaluator / IAM policy / entry adapter'; break }
            '/Authorization/' { 'IAM.Access'; break }
            default { 'IAM composition/persistence/shared internal support' }
        }
        [ordered]@{
            path = $path; gitBlob = $blob; targetResponsibility = $owner
            projectReferences = @([regex]::Matches($content, '<ProjectReference Include="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
            registrations = @($content -split "`n" | Where-Object { $_ -match 'services\.Add(Scoped|Singleton|Transient|KeyedScoped|HttpClient)|AddJwtBearer|AddAuthentication' } | ForEach-Object { $_.Trim() })
            endpoints = @($content -split "`n" | Where-Object { $_ -match '\.Map(Get|Post|Put|Delete|Patch|Group)\(' } | ForEach-Object { $_.Trim() })
        }
    }
    $catalog = ((& git show "${commit}:docs/architecture/review/gates/G03/contract-event-catalog.yaml") -join "`n") | ConvertFrom-Json -Depth 100
    $manifest = ((& git show "${commit}:deployment/g04/module-manifest.json") -join "`n") | ConvertFrom-Json -Depth 100
    $inventory = [ordered]@{
        formatVersion = 1; plan = '05-iam-platform-security-refactor'; slice = 'P05-S0'
        baselineCommit = $commit; scope = 'repository-source-and-test-inventory'
        sourceCount = @($sources).Count; sources = @($sources)
        authCatalogEntry = @($catalog.modules | Where-Object id -eq 'auth')
        authRuntimeEntry = @($manifest.modules | Where-Object moduleId -eq 'auth')
        migrationFiles = @($paths | Where-Object { $_ -match '^src/Modules/Auth/.*/Persistence/Migrations/.*\.cs$' })
        testFiles = @($paths | Where-Object { $_ -match '^tests/.*(Auth|Security|Tenant|Policy|Context|Migration).*\.cs$' })
        targetDatabase = [ordered]@{ status = 'not-inspected'; reason = 'No target database selected; no production credentials read. Use the read-only preflight before data cutover.' }
        authoritativeSources = @('docs/architecture/review/gates/G03/contract-event-catalog.yaml', 'deployment/g04/module-manifest.json', 'src/layerguard.json')
    }
    $output = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $repositoryRoot $OutputPath }
    New-Item -ItemType Directory -Force -Path (Split-Path $output) | Out-Null
    $inventory | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $output -Encoding utf8
    Write-Host "Plan 05 inventory: $(@($sources).Count) source files at $commit. Target data not claimed."
}
finally { Pop-Location }
