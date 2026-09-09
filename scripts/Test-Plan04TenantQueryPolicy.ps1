[CmdletBinding()]
param(
    [string] $PolicyPath = 'docs/architecture/review/policies/plan04/tenant-query-policy.json',
    [string] $BypassRegistryPath = 'docs/architecture/review/policies/plan04/tenant-query-bypass-registry.json',
    [string] $InventoryPath = 'docs/architecture/review/evidence/plan04/tenant-query-inventory.json',
    [string] $StatusPath = 'docs/architecture/review/evidence/plan04/phase4-tenant-query-status.json'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
function Repo([string] $path) {
    if ([IO.Path]::IsPathRooted($path)) { return $path }
    return Join-Path $repositoryRoot $path
}
function Sha256([string] $path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath (Repo $path)).Hash.ToLowerInvariant()
}
function Text-Present([object] $value) { return -not [string]::IsNullOrWhiteSpace([string]$value) }
function Relative([string] $path) { return [IO.Path]::GetRelativePath($repositoryRoot, $path).Replace('\', '/') }

function Get-MethodBlocks([string] $path) {
    $lines = @(Get-Content -LiteralPath $path)
    $blocks = @()
    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
        if ($lines[$lineIndex] -notmatch '^    public .*Task') { continue }
        $signatureEnd = $lineIndex
        $signature = $lines[$lineIndex]
        while ($signature -notmatch '\)' -and $signatureEnd + 1 -lt $lines.Count) {
            $signatureEnd++
            $signature += ' ' + $lines[$signatureEnd]
        }
        $blockEnd = $lines.Count - 1
        for ($candidate = $signatureEnd + 1; $candidate -lt $lines.Count; $candidate++) {
            if ($lines[$candidate] -match '^    public ') { $blockEnd = $candidate - 1; break }
        }
        $blocks += [pscustomobject]@{
            Signature = $signature
            Body = ($lines[$signatureEnd..$blockEnd] -join "`n")
            Line = $lineIndex + 1
        }
    }
    return $blocks
}

function Validate-Fixture([string] $text) {
    $errors = [Collections.Generic.List[string]]::new()
    if ($text -match 'Guid\?\s+tenantId') { $errors.Add('nullable-tenant') }
    if ($text -match 'Guid\s+tenantId\s*=\s*default') { $errors.Add('default-tenant') }
    if ($text -match 'bypassTenant|IgnoreQueryFilters') { $errors.Add('ordinary-bypass') }
    if ($text -match 'Guid\s+tenantId' -and $text -notmatch 'TenantQueryGuard\.Require\(tenantId\)') { $errors.Add('missing-tenant-guard') }
    if ($text -match 'Guid\s+tenantId' -and $text -notmatch 'TenantId\s*==\s*tenantId') { $errors.Add('missing-tenant-predicate') }
    return @($errors | Sort-Object -Unique)
}

$policy = Get-Content -Raw -LiteralPath (Repo $PolicyPath) | ConvertFrom-Json -Depth 100
$registry = Get-Content -Raw -LiteralPath (Repo $BypassRegistryPath) | ConvertFrom-Json -Depth 100
$repositoryFiles = @(Get-ChildItem -LiteralPath (Repo 'src/Modules') -Recurse -File -Filter '*Repository.cs' |
    Where-Object FullName -Match 'Infrastructure.*[\\/]Repositories')
$businessFiles = @($repositoryFiles | Where-Object FullName -Match 'Modules[\\/](CRM|Registry|Holdings|Transaction)[\\/]')
$tenantMethods = @()
$tenantFindings = @()
foreach ($file in $repositoryFiles) {
    foreach ($method in @(Get-MethodBlocks $file.FullName)) {
        if ($method.Signature -notmatch 'Guid tenantId' -or $method.Body -notmatch '_context\.') { continue }
        $guarded = $method.Body -match 'TenantQueryGuard\.Require\(tenantId\)'
        $predicated = $method.Body -match 'TenantId\s*==\s*tenantId|tenantId\s*==\s*\w+\.TenantId|\.Id\s*==\s*tenantId'
        $record = [ordered]@{
            file = Relative $file.FullName
            line = $method.Line
            signature = $method.Signature.Trim()
            guarded = $guarded
            predicated = $predicated
        }
        $tenantMethods += $record
        if (-not $guarded -or -not $predicated) { $tenantFindings += $record }
    }
}

$contractFiles = @(Get-ChildItem -LiteralPath (Repo 'src/Modules') -Recurse -File -Filter '*Repository.cs' |
    Where-Object FullName -Match 'Domain|Contracts')
$contractText = ($contractFiles | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"
$nullableOrDefaultCount = @([regex]::Matches($contractText, 'Guid\?\s+tenantId|Guid\s+tenantId\s*=\s*default')).Count
$sourceFiles = @(Get-ChildItem -LiteralPath (Repo 'src') -Recurse -File -Filter '*.cs')
$sourceText = ($sourceFiles | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName }) -join "`n"
$ignoreQueryFiltersCount = @([regex]::Matches($sourceText, '\.IgnoreQueryFilters\s*\(')).Count
$ordinaryBypassFlagCount = @([regex]::Matches($contractText, 'bypassTenant|ignoreTenant')).Count
$tenantOwnedContractExpectations = [ordered]@{
    'src/Modules/Auth/IFX.Modules.Auth.Domain/Authorization/IRoleRepository.cs' = @(
        'GetByIdAsync\(Guid id, Guid tenantId',
        'GetByNameAsync\(string name, Guid tenantId',
        'GetByIdWithPermissionsAsync\(Guid id, Guid tenantId')
    'src/Modules/Auth/IFX.Modules.Auth.Domain/Authorization/IRoleGroupRepository.cs' = @(
        'GetByIdAsync\(Guid id, Guid tenantId',
        'GetByNameAsync\(string name, Guid tenantId',
        'GetByIdWithRolesAsync\(Guid id, Guid tenantId')
    'src/Modules/Auth/IFX.Modules.Auth.Domain/Authorization/IDepartmentRepository.cs' = @(
        'GetByIdAsync\(Guid id, Guid tenantId')
    'src/Modules/Auth/IFX.Modules.Auth.Domain/Authorization/IPolicyDefinitionRepository.cs' = @(
        'GetTenantByIdAsync\(Guid id, Guid tenantId')
    'src/Modules/Auth/IFX.Modules.Auth.Domain/Identity/IIdpRepository.cs' = @(
        'GetByIdAsync\(Guid id, Guid tenantId')
    'src/Modules/CRM/IFX.Modules.CRM.Domain/Repositories/IIndividualInvestorProfileRepository.cs' = @(
        'GetByInvestorIdAsync\(Guid investorId, Guid tenantId')
    'src/Modules/CRM/IFX.Modules.CRM.Domain/Repositories/ICorporateInvestorProfileRepository.cs' = @(
        'GetByInvestorIdAsync\(Guid investorId, Guid tenantId')
    'src/Modules/CRM/IFX.Modules.CRM.Domain/Repositories/ITrustInvestorProfileRepository.cs' = @(
        'GetByInvestorIdAsync\(Guid investorId, Guid tenantId')
    'src/Modules/Holdings/IFX.Modules.Holdings.Domain/Repositories/IHoldingRepository.cs' = @(
        'GetByIdAsync\(Guid tenantId, Guid holdingId')
    'src/Modules/Transaction/IFX.Modules.Transaction.Domain/Repositories/IOrderRepository.cs' = @(
        'GetByIdAsync\(Guid tenantId, Guid orderId',
        'GetByIdWithLegsAsync\(Guid tenantId, Guid orderId')
    'src/Modules/Transaction/IFX.Modules.Transaction.Domain/Repositories/ITransactionRepository.cs' = @(
        'GetByIdAsync\(Guid tenantId, Guid transactionId')
}
$tenantOwnedContractResults = @()
foreach ($contractPath in $tenantOwnedContractExpectations.Keys) {
    $text = Get-Content -Raw -LiteralPath (Repo $contractPath)
    foreach ($pattern in $tenantOwnedContractExpectations[$contractPath]) {
        $tenantOwnedContractResults += [ordered]@{
            file = $contractPath
            pattern = $pattern
            passed = $text -match $pattern
        }
    }
}

$bypassResults = @()
foreach ($entry in @($registry.entries)) {
    $repositoryParts = ([string]$entry.repositoryMethod).Split('.')
    $interfaceName = $repositoryParts[0]
    $methodName = $repositoryParts[-1]
    $interfaceFound = $contractText -match ([regex]::Escape($methodName) + '\(int maxRows')
    $implementationMatches = @($repositoryFiles | Where-Object {
        $_.BaseName -eq $interfaceName.Substring(1) -and
        (Get-Content -Raw -LiteralPath $_.FullName) -match ([regex]::Escape($methodName) + '\(int maxRows')
    })
    $implementationOk = $implementationMatches.Count -eq 1 -and
        (Get-Content -Raw -LiteralPath $implementationMatches[0].FullName) -match 'RequireBoundedLimit\(maxRows\)' -and
        (Get-Content -Raw -LiteralPath $implementationMatches[0].FullName) -match 'Take\(maxRows\)'
    $handlerMatches = @($sourceFiles | Where-Object Name -eq ($entry.handler + '.cs'))
    $handlerText = if ($handlerMatches.Count -eq 1) { Get-Content -Raw -LiteralPath $handlerMatches[0].FullName } else { '' }
    $handlerOk = $handlerText -match 'CrossTenantAccessGuard\.Require' -and
        $handlerText -match [regex]::Escape([string]$entry.purpose) -and
        $handlerText -match 'ActorUserId'
    $endpointText = Get-Content -Raw -LiteralPath (Repo 'src/Modules/Auth/IFX.Modules.Auth.Presentation/Authorization/Endpoints/GlobalRoleEndpointExtensions.cs')
    $endpointRoute = ([string]$entry.endpoint).Replace('/api/v1/platform', '')
    $endpointOk = $endpointText -match [regex]::Escape($endpointRoute) -and
        $endpointText -match 'ExecutionScopeRequirement\.Platform' -and
        $endpointText -match [regex]::Escape([string]$entry.permission)
    $metadataOk = (Text-Present $entry.owner) -and (Text-Present $entry.purpose) -and
        (Text-Present $entry.audit) -and $entry.maximumRows -eq $policy.crossTenantRequirements.maximumRows -and
        [datetime]$entry.expiresAt -gt [datetime]'2026-09-10'
    $bypassResults += [ordered]@{
        id = $entry.id
        repositoryMethod = $entry.repositoryMethod
        interfaceFound = $interfaceFound
        implementationBounded = $implementationOk
        handlerAuthorizedAndAudited = $handlerOk
        endpointPlatformAuthorized = $endpointOk
        metadataComplete = $metadataOk
        passed = $interfaceFound -and $implementationOk -and $handlerOk -and $endpointOk -and $metadataOk
    }
}
$registeredMethodNames = @($registry.entries.repositoryMethod | ForEach-Object { ([string]$_).Split('.')[-1] } | Sort-Object -Unique)
$declaredAcrossTenantMethods = @([regex]::Matches($contractText, '\b(?:Get\w*)?AcrossTenants\w*Async\b') | ForEach-Object Value | Sort-Object -Unique)
$unregisteredAcrossTenantMethods = @($declaredAcrossTenantMethods | Where-Object { $_ -notin $registeredMethodNames })

$fixtureExpectations = [ordered]@{
    'tenant-positive-explicit.txt' = @()
    'tenant-negative-missing-predicate.txt' = @('missing-tenant-predicate')
    'tenant-negative-nullable.txt' = @('nullable-tenant')
    'tenant-negative-default.txt' = @('default-tenant','missing-tenant-guard')
    'tenant-negative-bypass.txt' = @('ordinary-bypass')
}
$fixtureResults = @()
foreach ($fixture in $fixtureExpectations.Keys) {
    $actual = @(Validate-Fixture (Get-Content -Raw -LiteralPath (Repo "tests/Architecture/Plan04/Fixtures/$fixture")))
    $expected = @($fixtureExpectations[$fixture] | Sort-Object)
    $fixtureResults += [ordered]@{
        fixture = $fixture
        expectedErrors = $expected
        actualErrors = $actual
        passed = ($expected -join '|') -eq ($actual -join '|')
    }
}

$inventory = [ordered]@{
    formatVersion = 1
    generatedAt = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    strategy = $policy.defaultStrategy
    repositoryFileCount = $repositoryFiles.Count
    businessRepositoryFileCount = $businessFiles.Count
    tenantQueryMethodCount = $tenantMethods.Count
    tenantQueryMethods = $tenantMethods
    tenantFindings = $tenantFindings
    crossTenantEntries = $bypassResults
    classifications = $policy.identityAndPlatformClassifications
    ignoreQueryFiltersCount = $ignoreQueryFiltersCount
    ordinaryBypassFlagCount = $ordinaryBypassFlagCount
    unregisteredAcrossTenantMethods = $unregisteredAcrossTenantMethods
    tenantOwnedContractResults = $tenantOwnedContractResults
}
$resolvedInventory = Repo $InventoryPath
$inventory | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedInventory -Encoding utf8NoBOM

$checks = [ordered]@{
    policyDefaultsToExplicitPredicate = $policy.defaultStrategy -eq 'explicit-tenant-predicate'
    trustedNonNullableTenantRequired = $policy.tenantIdentity.source -eq 'trusted-execution-context' -and
        $policy.tenantIdentity.nullableAllowed -eq $false -and $policy.tenantIdentity.defaultAllowed -eq $false
    tenantMethodsGuardedAndPredicated = $tenantMethods.Count -gt 0 -and $tenantFindings.Count -eq 0
    contractsHaveNoNullableOrDefaultTenant = $nullableOrDefaultCount -eq 0
    tenantOwnedContractSignaturesExplicit = @($tenantOwnedContractResults | Where-Object passed -ne $true).Count -eq 0
    noOrdinaryBypassFlags = $ordinaryBypassFlagCount -eq 0
    noIgnoreQueryFilters = $ignoreQueryFiltersCount -eq 0
    bypassRegistryComplete = @($registry.entries).Count -eq 5 -and @($bypassResults | Where-Object passed -ne $true).Count -eq 0
    noUnregisteredCrossTenantRepository = $unregisteredAcrossTenantMethods.Count -eq 0
    negativeFixturesPass = @($fixtureResults | Where-Object passed -ne $true).Count -eq 0
    globalFilterDecisionRecorded = $policy.globalQueryFilterDecision.status -eq 'not-selected' -and @($policy.globalQueryFilterDecision.revisitWhen).Count -ge 4
    rlsExplicitlyNotClaimed = $policy.rlsDecision.status -eq 'deferred-not-claimed' -and @($policy.rlsDecision.requiredBeforeAdoption).Count -ge 5
}
$failed = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object Key)
$status = [ordered]@{
    formatVersion = 1
    plan = '04-module-boundary-evolution'
    slice = 'P04-S4'
    result = if ($failed.Count -eq 0) { 'repository-passed-production-rls-not-claimed' } else { 'failed' }
    checkedAt = (Get-Date).ToString('yyyy-MM-dd')
    policySha256 = Sha256 $PolicyPath
    bypassRegistrySha256 = Sha256 $BypassRegistryPath
    inventorySha256 = Sha256 $InventoryPath
    checks = $checks
    fixtureResults = $fixtureResults
    metrics = [ordered]@{
        repositoryFiles = $repositoryFiles.Count
        tenantQueryMethods = $tenantMethods.Count
        registeredCrossTenantEntries = @($registry.entries).Count
        findings = $tenantFindings.Count + $unregisteredAcrossTenantMethods.Count
    }
    globalQueryFilter = $policy.globalQueryFilterDecision.status
    rls = $policy.rlsDecision.status
    productionValidation = 'not-run-not-claimed'
    failedChecks = $failed
}
$resolvedStatus = Repo $StatusPath
$status | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedStatus -Encoding utf8NoBOM
if ($failed.Count -gt 0) { throw "Plan 04 tenant-query validation failed: $($failed -join ', '). Report: $resolvedStatus" }
Write-Host "Plan 04 tenant-query result: $($status.result). Report: $resolvedStatus"
