[CmdletBinding()]
param([string] $ReportPath = 'artifacts/plan05/security-boundary.json')
$ErrorActionPreference = 'Stop'
$root = if ($env:GUARD_TARGET_ROOT) { [IO.Path]::GetFullPath($env:GUARD_TARGET_ROOT) } else { [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../../../../..')) }
function Read-Source([string] $relative) { Get-Content -LiteralPath (Join-Path $root $relative) -Raw }
function Pure-Contract([string] $source) {
    # The standard SDK declaration is build metadata, not a dependency on a Microsoft framework type.
    $source.Replace('Sdk="Microsoft.NET.Sdk"','') -notmatch 'Microsoft\.|Amazon\.|Auth0\.|System\.Text\.Json|ClaimsPrincipal|HttpContext|IQueryable|DbContext|IServiceCollection|PackageReference|ProjectReference|\.Infrastructure\.'
}
function Neutral-Runtime([string] $source) {
    $source -notmatch 'IFX\.Modules\.|IHttpContextAccessor|HttpContext\.Current|EntityFrameworkCore|DbContext'
}
function Files-In([string] $relative) {
    @(Get-ChildItem -LiteralPath (Join-Path $root $relative) -Recurse -File | Where-Object {
        $_.Extension -in '.cs','.csproj' -and $_.FullName -notmatch '[\\/](bin|obj)[\\/]'
    })
}
$checks = [ordered]@{}
$selfTests = @(
    @{ Kind='contract'; Source='public record Request(string Id);'; Expected=$true },
    @{ Kind='contract'; Source='public record Request(Microsoft.AspNetCore.Http.HttpContext Context);'; Expected=$false },
    @{ Kind='contract'; Source='using Amazon.CognitoIdentityProvider;'; Expected=$false },
    @{ Kind='contract'; Source='using IFX.Platform.Authorization.Infrastructure.Opa;'; Expected=$false },
    @{ Kind='contract'; Source='public record Policy(System.Text.Json.JsonElement Value);'; Expected=$false },
    @{ Kind='contract'; Source='<PackageReference Include="SomeSdk" />'; Expected=$false },
    @{ Kind='runtime'; Source='using IFX.Platform.Authorization.Contracts.V1;'; Expected=$true },
    @{ Kind='runtime'; Source='using IFX.Modules.IAM.Infrastructure.Persistence;'; Expected=$false },
    @{ Kind='runtime'; Source='public class Runtime(IHttpContextAccessor context);'; Expected=$false },
    @{ Kind='runtime'; Source='public class Runtime(DbContext db);'; Expected=$false }
)
$checks.positiveAndNegativeDetectors = @($selfTests | Where-Object {
    $actual = if ($_.Kind -eq 'contract') { Pure-Contract $_.Source } else { Neutral-Runtime $_.Source }
    $actual -ne $_.Expected
}).Count -eq 0
$bindings = @()
foreach ($capability in 'Authentication','Authorization') {
    $contracts = Files-In "src/Platform/$capability/IFX.Platform.$capability.Contracts"
    $runtime = Files-In "src/Platform/$capability/IFX.Platform.$capability.Runtime"
    $checks["${capability}ContractsArePure"] = $contracts.Count -gt 0 -and @($contracts | Where-Object { -not (Pure-Contract (Get-Content $_.FullName -Raw)) }).Count -eq 0
    $checks["${capability}RuntimeHasNoBusinessOrHttpDependency"] = $runtime.Count -gt 0 -and @($runtime | Where-Object { -not (Neutral-Runtime (Get-Content $_.FullName -Raw)) }).Count -eq 0
    $bindings += @($contracts + $runtime)
}
$identityRegistration = Read-Source 'src/Modules/IAM/IFX.Modules.IAM.Infrastructure/DependencyInjection.cs'
$facts = Read-Source 'src/Modules/IAM/IFX.Modules.IAM.Infrastructure/Access/VerifiedIdentityFacts.cs'
$actor = Read-Source 'src/Modules/IAM/IFX.Modules.IAM.Infrastructure/Access/HttpIdentityFacts.cs'
$permission = Read-Source 'src/Modules/IAM/IFX.Modules.IAM.Infrastructure/Access/PermissionChecker.cs'
$resource = Read-Source 'src/Modules/IAM/IFX.Modules.IAM.Infrastructure/Integrations/Inbound/ResourceAuthorizationInboundAdapter.cs'
$hostSource = Read-Source 'src/ApiHost/IFX.ApiHost/Program.cs'
$handler = Read-Source 'src/ApiHost/IFX.ApiHost/Authorization/PermissionAuthorizationHandler.cs'
$checks.verifiedIdentityIsTheProductionSource = $identityRegistration -match 'AddScoped<IExecutionIdentityFacts>.*GetRequiredService<VerifiedIdentityFacts>' -and $identityRegistration -notmatch 'AddScoped<IExecutionIdentityFacts>.*GetRequiredService<HttpIdentityFacts>'
$checks.membershipFactsAreCurrentAndTenantBound = $facts -match 'IsAuthenticated.*Refresh\(' -and $facts -match 'AsNoTracking\(' -and $facts -match 't.Id == tenantId && t.IsActive' -and $facts -match 'r.TenantId == tenant' -and $facts -notmatch 'IMemoryCache|IDistributedCache|FindAll\('
$checks.workerActorRequiresTrustedUserIdentity = $actor -match 'ContextProvenance.Trusted' -and $actor -match 'ActorKind.User' -and $actor -match 'Guid.TryParse'
$checks.internalAuthorizationRequiresExplicitContext = $permission -match '_execution.HasCurrent' -and $permission -match 'ActorKind.User' -and $permission -match '_currentUser.TenantId == _execution.Current.TenantId' -and $resource -match 'contextValidator.Validate' -and $resource -match 'ContractTenantValidation.MatchWhenTenantScoped' -and $resource -match 'contract_context_invalid'
$checks.httpUsesIamDecision = $handler -match 'IPermissionChecker' -and $handler -match 'HasPermissionAsync' -and $handler -notmatch 'HasClaim|GlobalRoles'
$checks.hostUsesIamComposition = $hostSource -match 'AddIamModule' -and $hostSource -notmatch 'AddOpaClient|AddAuthModule|IFX.Modules.IAM.(Application|Infrastructure|Presentation)'
$checks.retiredTransitionTypesAreAbsent = -not (Test-Path (Join-Path $root 'src/Modules/IAM/IFX.Modules.IAM.Application/Access/Abac/Resolver/IAbacPolicyCache.cs')) -and -not (Test-Path (Join-Path $root 'src/ApiHost/IFX.ApiHost/Configuration/OpaConfiguration.cs'))
$compatibility = Read-Source 'docs/architecture/review/evidence/plan05/compatibility-identifiers.json' | ConvertFrom-Json -Depth 20
$legacyFindings = @(foreach ($file in (Files-In 'src')) {
    $relative = [IO.Path]::GetRelativePath($root,$file.FullName).Replace('\','/')
    foreach ($line in @(Get-Content $file.FullName | Where-Object { $_ -match 'IFX\.Modules\.Auth\b' })) {
        if (@($compatibility.legacyTypeReferences | Where-Object { $_.path -eq $relative -and $line.Contains($_.value) }).Count -ne 1) { $relative }
    }
})
$checks.legacyTypeNamesHaveExactCompatibilityEntries = $legacyFindings.Count -eq 0 -and @($compatibility.legacyTypeReferences).Count -eq 1
$sourceFiles = @($bindings | Sort-Object FullName -Unique | ForEach-Object {
    [ordered]@{ path=[IO.Path]::GetRelativePath($root,$_.FullName).Replace('\','/'); sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant() }
})
$report = [ordered]@{ phase='P05-S6'; result=if ($checks.Values -contains $false) {'failed'} else {'passed'}; checks=$checks; detectorCases=$selfTests.Count; sourceBindings=$sourceFiles; runtimeTests='SQL membership revocation, IAM mandatory/contract context, platform unknown attributes and composition tests run separately'; namedApprovals='not-inferred' }
$output = if ([IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $root $ReportPath }
New-Item -ItemType Directory -Force (Split-Path -Parent $output) | Out-Null
$report | ConvertTo-Json -Depth 20 | Set-Content $output -Encoding utf8NoBOM
if ($report.result -ne 'passed') { throw "Plan 05 security boundary failed: $output" }
Write-Host "Plan 05 security boundary passed: $output"
