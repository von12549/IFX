# Plan: Pluggable Identity Providers for Auth Module

**Date:** 2026-03-16
**Branch:** `feature/pluggable-identity-providers`
**Status:** Ready for implementation

---

## Goal

Refactor the Auth module so that identity providers (Cognito, Auth0) are infrastructure adapters. Switching provider requires only a configuration change and infrastructure wiring — no changes to Domain or Application.

---

## Current State

### Problems to fix

1. **`ICognitoService`** lives in `Auth.Application` but its name and return types (`CognitoSignUpResult`, `CognitoAuthResult`, `CognitoUserInfo`) are vendor-specific. Application handlers that use it are coupled to Cognito naming.

2. **Infrastructure is flat** — Cognito code lives in `Identity/Services/` and `Identity/Configuration/` with no provider isolation. Adding Auth0 would scatter its files in the same directories.

3. **No configuration-driven provider selection** — `Infrastructure.DependencyInjection` always wires Cognito unconditionally.

### What is already good

- `IOidcAuthService` — already provider-neutral in name and contract. Keep as-is.
- `IOidcDiscoveryService` — generic RFC 8414 implementation. Keep as-is.
- `IIdpCacheInvalidator`, `IEmailVerificationService` — not provider-specific. Keep as-is.
- All domain and repository types — no provider SDK references. No changes needed.

---

## Target State

### Application layer abstractions (provider-neutral)

| New Name | Replaces | File |
|----------|----------|------|
| `IIdentityProvider` | `ICognitoService` | `Application/Identity/Interfaces/IIdentityProvider.cs` |
| `ProviderSignUpResult` | `CognitoSignUpResult` | (same file as interface) |
| `AuthTokenResult` | `CognitoAuthResult` | (same file as interface) |
| `ProviderUserInfo` | `CognitoUserInfo` | (same file as interface) |

`IOidcAuthService`, `IOidcDiscoveryService`, `IIdpCacheInvalidator` — **unchanged**.

### Infrastructure folder structure (after)

```
Auth.Infrastructure
  IdentityProviders/
    Cognito/
      CognitoIdentityProvider.cs          ← was Identity/Services/CognitoService.cs
      CognitoOidcService.cs               ← was Identity/Services/CognitoOidcService.cs
      CognitoOptions.cs                   ← was Identity/Configuration/CognitoSettings.cs
      CognitoOidcOptions.cs               ← was Identity/Configuration/CognitoOidcSettings.cs
      CognitoServiceCollectionExtensions.cs ← new (extracted from DependencyInjection.cs)
    Auth0/
      Auth0IdentityProvider.cs            ← new stub
      Auth0OidcService.cs                 ← new stub
      Auth0Options.cs                     ← new stub
      Auth0ServiceCollectionExtensions.cs ← new stub
  Identity/
    Services/
      OidcDiscoveryService.cs             ← unchanged (not provider-specific)
    ...
```

Files removed (after content moved):
- `Identity/Services/CognitoService.cs`
- `Identity/Services/CognitoOidcService.cs`
- `Identity/Configuration/CognitoSettings.cs`
- `Identity/Configuration/CognitoOidcSettings.cs`

### Composition: configuration-driven provider selection

`appsettings.json` / environment override:
```json
{
  "Authentication": {
    "Provider": "Cognito"
  }
}
```

`AuthModuleInstaller.InstallServices()` reads `Authentication:Provider` and calls the appropriate extension method.

---

## Implementation Steps

### Step 1 — Rename Application interface and DTOs

**File: `IFX.Modules.Auth.Application/Identity/Interfaces/IIdentityProvider.cs`** (new file, replaces `ICognitoService.cs`)

- Rename interface `ICognitoService` → `IIdentityProvider`
- Rename `CognitoSignUpResult` → `ProviderSignUpResult`
- Rename `CognitoAuthResult` → `AuthTokenResult`
- Rename `CognitoUserInfo` → `ProviderUserInfo`
- Keep all method signatures unchanged (only names of interface and DTOs change)
- Delete `ICognitoService.cs`

**Handlers to update** (all in `Application/Identity/Commands/`):

| Handler | Old reference | New reference |
|---------|--------------|---------------|
| `RegisterUserCommandHandler` | `ICognitoService`, `CognitoSignUpResult` | `IIdentityProvider`, `ProviderSignUpResult` |
| `LoginUserCommandHandler` | `ICognitoService`, `CognitoAuthResult` | `IIdentityProvider`, `AuthTokenResult` |
| `ConfirmRegistrationCommandHandler` | `ICognitoService` | `IIdentityProvider` |
| `LogoutUserCommandHandler` | `ICognitoService` | `IIdentityProvider` |
| `RefreshTokenCommandHandler` | `ICognitoService`, `CognitoAuthResult` | `IIdentityProvider`, `AuthTokenResult` |
| `RevokeTokenCommandHandler` | `ICognitoService` | `IIdentityProvider` |
| `ResendEmailVerificationCommandHandler` | `ICognitoService` | `IIdentityProvider` |
| `SyncUserCommandHandler` | `ICognitoService`, `CognitoUserInfo` | `IIdentityProvider`, `ProviderUserInfo` |

**Namespace:** keep `IFX.Modules.Auth.Application.Identity.Interfaces`

---

### Step 2 — Create `IdentityProviders/Cognito/` in Infrastructure

#### 2a. `CognitoOptions.cs`

Rename from `CognitoSettings.cs`:
- Class `CognitoSettings` → `CognitoOptions`
- `SectionName` constant stays as `"CognitoSettings"` (no config key change, backward-compatible)
- New namespace: `IFX.Modules.Auth.Infrastructure.IdentityProviders.Cognito`

#### 2b. `CognitoOidcOptions.cs`

Rename from `CognitoOidcSettings.cs`:
- Class `CognitoOidcSettings` → `CognitoOidcOptions`
- `SectionName` constant stays as `"CognitoOidcSettings"` (backward-compatible)
- New namespace: `IFX.Modules.Auth.Infrastructure.IdentityProviders.Cognito`

#### 2c. `CognitoIdentityProvider.cs`

Move + rename from `CognitoService.cs`:
- Class `CognitoService` → `CognitoIdentityProvider`
- Implements `IIdentityProvider` (was `ICognitoService`)
- Update return types: `CognitoSignUpResult` → `ProviderSignUpResult`, etc.
- Update `using` for `CognitoOptions` (was `CognitoSettings`)
- New namespace: `IFX.Modules.Auth.Infrastructure.IdentityProviders.Cognito`

#### 2d. `CognitoOidcService.cs`

Move from `Identity/Services/CognitoOidcService.cs`:
- Class and filename unchanged (`CognitoOidcService`)
- Still implements `IOidcAuthService` (unchanged interface)
- Update `using` for `CognitoOidcOptions` (was `CognitoOidcSettings`)
- New namespace: `IFX.Modules.Auth.Infrastructure.IdentityProviders.Cognito`

#### 2e. `CognitoServiceCollectionExtensions.cs` (new file)

Extract Cognito-specific DI registration from `Infrastructure/DependencyInjection.cs`:

```csharp
namespace IFX.Modules.Auth.Infrastructure.IdentityProviders.Cognito;

public static class CognitoServiceCollectionExtensions
{
    public static IServiceCollection AddCognitoProvider(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.Configure<CognitoOptions>(...);
        services.Configure<CognitoOidcOptions>(...);
        services.AddSingleton<IAmazonCognitoIdentityProvider>(...);
        services.AddScoped<IIdentityProvider, CognitoIdentityProvider>();
        services.AddHttpClient("CognitoOidc", ...);
        services.AddScoped<IOidcAuthService, CognitoOidcService>();
        return services;
    }
}
```

---

### Step 3 — Create `IdentityProviders/Auth0/` stubs in Infrastructure

These are placeholder implementations. All methods throw `NotImplementedException` with a clear message. This satisfies the structural requirement without false behavior.

#### 3a. `Auth0Options.cs`

```csharp
namespace IFX.Modules.Auth.Infrastructure.IdentityProviders.Auth0;

public class Auth0Options
{
    public const string SectionName = "Auth0";
    public string Domain { get; set; } = string.Empty;
    public string ClientId { get; set; } = string.Empty;
    public string ClientSecret { get; set; } = string.Empty;
    public string Audience { get; set; } = string.Empty;
    public string CallbackUrl { get; set; } = string.Empty;
    public string LogoutCallbackUrl { get; set; } = string.Empty;
}
```

#### 3b. `Auth0IdentityProvider.cs`

- Implements `IIdentityProvider`
- All methods: `throw new NotImplementedException("Auth0 provider is not yet implemented.")`
- Namespace: `IFX.Modules.Auth.Infrastructure.IdentityProviders.Auth0`

#### 3c. `Auth0OidcService.cs`

- Implements `IOidcAuthService`
- All methods: `throw new NotImplementedException("Auth0 OIDC service is not yet implemented.")`
- Namespace: `IFX.Modules.Auth.Infrastructure.IdentityProviders.Auth0`

#### 3d. `Auth0ServiceCollectionExtensions.cs`

```csharp
namespace IFX.Modules.Auth.Infrastructure.IdentityProviders.Auth0;

public static class Auth0ServiceCollectionExtensions
{
    public static IServiceCollection AddAuth0Provider(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.Configure<Auth0Options>(configuration.GetSection(Auth0Options.SectionName));
        services.AddHttpClient("Auth0Oidc", client =>
        {
            client.DefaultRequestHeaders.Add("Accept", "application/json");
        });
        services.AddScoped<IIdentityProvider, Auth0IdentityProvider>();
        services.AddScoped<IOidcAuthService, Auth0OidcService>();
        return services;
    }
}
```

---

### Step 4 — Update `Infrastructure/DependencyInjection.cs`

Remove from `AddInfrastructureServices()`:
- All `CognitoSettings`, `CognitoOidcSettings` configuration
- `IAmazonCognitoIdentityProvider` registration
- `ICognitoService` / `IIdentityProvider` registration
- `IOidcAuthService` registration
- `"CognitoOidc"` HttpClient registration

Keep in `AddInfrastructureServices()` (shared, not provider-specific):
- `IMemoryCache` registration
- `"OidcDiscovery"` HttpClient
- `IOidcDiscoveryService`
- `IEmailVerificationService`, `IEmailVerificationCleanupService`
- DbContext
- All repository registrations
- `IUnitOfWork`

Add a parameter `Action<IServiceCollection, IConfiguration> providerRegistrar` that is called from Composition, OR expose the method signature to accept the provider name. See Step 5 for how Composition drives this.

---

### Step 5 — Update `Composition/AuthModuleInstaller.cs`

`InstallServices()` reads provider from config and delegates to the right extension:

```csharp
public IServiceCollection InstallServices(IServiceCollection services, IConfiguration configuration)
{
    services.AddApplicationServices();
    services.AddInfrastructureServices(configuration);

    var provider = configuration["Authentication:Provider"] ?? "Cognito";
    switch (provider.ToLowerInvariant())
    {
        case "cognito":
            services.AddCognitoProvider(configuration);
            break;
        case "auth0":
            services.AddAuth0Provider(configuration);
            break;
        default:
            throw new InvalidOperationException(
                $"Unknown identity provider '{provider}'. Valid values: Cognito, Auth0.");
    }

    services.AddScoped<IAppMigrator, AuthMigrator>();
    return services;
}
```

Add required `using` statements for both provider extension types.

---

### Step 6 — Clean up old Infrastructure files

Delete after content has been moved and all references updated:
- `src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Identity/Services/CognitoService.cs`
- `src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Identity/Services/CognitoOidcService.cs`
- `src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Identity/Configuration/CognitoSettings.cs`
- `src/Modules/Auth/IFX.Modules.Auth.Infrastructure/Identity/Configuration/CognitoOidcSettings.cs`
- `src/Modules/Auth/IFX.Modules.Auth.Application/Identity/Interfaces/ICognitoService.cs`

---

### Step 7 — Build and verify

```bash
dotnet build IFX.sln
dotnet test IFX.sln
```

All 252 tests must pass. No Cognito types should appear in Application or Domain.

---

## File Change Catalog

### Auth.Application

| Action | File |
|--------|------|
| Create | `Identity/Interfaces/IIdentityProvider.cs` |
| Delete | `Identity/Interfaces/ICognitoService.cs` |
| Modify | `Identity/Commands/RegisterUser/RegisterUserCommandHandler.cs` |
| Modify | `Identity/Commands/LoginUser/LoginUserCommandHandler.cs` |
| Modify | `Identity/Commands/ConfirmRegistration/ConfirmRegistrationCommandHandler.cs` |
| Modify | `Identity/Commands/LogoutUser/LogoutUserCommandHandler.cs` |
| Modify | `Identity/Commands/RefreshToken/RefreshTokenCommandHandler.cs` |
| Modify | `Identity/Commands/RevokeToken/RevokeTokenCommandHandler.cs` |
| Modify | `Identity/Commands/ResendEmailVerification/ResendEmailVerificationCommandHandler.cs` |
| Modify | `Identity/Commands/SyncUser/SyncUserCommandHandler.cs` |

### Auth.Infrastructure

| Action | File |
|--------|------|
| Create | `IdentityProviders/Cognito/CognitoOptions.cs` |
| Create | `IdentityProviders/Cognito/CognitoOidcOptions.cs` |
| Create | `IdentityProviders/Cognito/CognitoIdentityProvider.cs` |
| Create | `IdentityProviders/Cognito/CognitoOidcService.cs` |
| Create | `IdentityProviders/Cognito/CognitoServiceCollectionExtensions.cs` |
| Create | `IdentityProviders/Auth0/Auth0Options.cs` |
| Create | `IdentityProviders/Auth0/Auth0IdentityProvider.cs` |
| Create | `IdentityProviders/Auth0/Auth0OidcService.cs` |
| Create | `IdentityProviders/Auth0/Auth0ServiceCollectionExtensions.cs` |
| Modify | `DependencyInjection.cs` (remove provider-specific code) |
| Delete | `Identity/Services/CognitoService.cs` |
| Delete | `Identity/Services/CognitoOidcService.cs` |
| Delete | `Identity/Configuration/CognitoSettings.cs` |
| Delete | `Identity/Configuration/CognitoOidcSettings.cs` |

### Auth.Composition

| Action | File |
|--------|------|
| Modify | `AuthModuleInstaller.cs` (add provider selection switch) |

### Configuration

| Action | File |
|--------|------|
| Modify | `appsettings.json` (add `Authentication:Provider = "Cognito"`) |
| Modify | `appsettings.Development.json` (add `Authentication:Provider = "Cognito"`) |
| Modify | `.env.example` (add `AUTHENTICATION_PROVIDER` + Auth0 variable block) |
| Modify | `docker-compose.yml` (pass `Authentication__Provider` env var to `auth-api` service) |

---

## Environment and Docker Changes

### Step 5b — Update `docker-compose.yml`

The `auth-api` service environment block currently has no `Authentication__Provider` variable, so the provider switch in `AuthModuleInstaller` would always fall back to the default. Add it alongside the existing Cognito block:

```yaml
# Identity Provider Selection
- Authentication__Provider=${AUTHENTICATION_PROVIDER:-Cognito}
# AWS Cognito
- CognitoSettings__UserPoolId=${COGNITO_USER_POOL_ID}
...
```

The `:-Cognito` default means existing deployments that have no `AUTHENTICATION_PROVIDER` in their `.env` continue to work without any change.

All existing `CognitoSettings__*` and `CognitoOidcSettings__*` entries are **unchanged** — the plan keeps the same config section names.

---

### Step 5c — Update `.env.example`

**Current state:** `.env.example` has an `# AWS COGNITO` section and no mention of provider selection.

**Changes needed:**

1. Add a provider selector variable at the top of the file (before the AWS Cognito block):

```dotenv
# =============================================================================
# IDENTITY PROVIDER
# =============================================================================
# Selects which identity provider implementation is active.
# Valid values: Cognito, Auth0
AUTHENTICATION_PROVIDER=Cognito
```

2. Add a commented-out Auth0 block after the Cognito section, so a developer switching to Auth0 knows what variables to set:

```dotenv
# =============================================================================
# AUTH0 (set AUTHENTICATION_PROVIDER=Auth0 to use)
# =============================================================================
# AUTH0_DOMAIN=your-tenant.auth0.com
# AUTH0_CLIENT_ID=your-client-id
# AUTH0_CLIENT_SECRET=your-client-secret
# AUTH0_AUDIENCE=https://your-api-identifier
# AUTH0_CALLBACK_URL=http://localhost:5000/api/v1/auth/oauth/callback
# AUTH0_LOGOUT_CALLBACK_URL=http://localhost:5000/api/v1/auth/oauth/logout-callback
```

The existing Cognito variables are **unchanged**.

---

## Dependency Rules After Refactor

```
Auth.Domain          → (nothing)
Auth.Application     → Auth.Domain
Auth.Infrastructure  → Auth.Application, Auth.Domain, Platform shared
Auth.Presentation    → Auth.Application
Auth.Composition     → Auth.Application, Auth.Infrastructure
```

No Cognito or Auth0 SDK types appear in Domain or Application. ✓

---

## Namespace Map After Refactor

```
IFX.Modules.Auth.Application.Identity.Interfaces
  IIdentityProvider          ← was ICognitoService
  IOidcAuthService           (unchanged)
  IOidcDiscoveryService      (unchanged)
  IIdpCacheInvalidator       (unchanged)
  IEmailVerificationService  (unchanged)

IFX.Modules.Auth.Infrastructure.IdentityProviders.Cognito
  CognitoIdentityProvider    ← was CognitoService
  CognitoOidcService         (moved, unchanged class name)
  CognitoOptions             ← was CognitoSettings
  CognitoOidcOptions         ← was CognitoOidcSettings
  CognitoServiceCollectionExtensions  (new)

IFX.Modules.Auth.Infrastructure.IdentityProviders.Auth0
  Auth0IdentityProvider      (new stub)
  Auth0OidcService           (new stub)
  Auth0Options               (new)
  Auth0ServiceCollectionExtensions  (new)
```

---

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Handler build errors after interface rename | Follow Step 1 before touching Infrastructure; build between steps |
| `OidcDiscoveryService` depends on `CognitoOidcSettings` for cache keys | It uses only the issuer string parameter — no settings dependency. Safe. |
| Namespace collision after moving files | All moved files get updated namespaces; no two files share the same qualified name |
| Tests fail after rename | Run `dotnet test` after Step 1 and Step 5; fix before proceeding |
| Config key `Authentication:Provider` missing in test/CI environments | Default to `"Cognito"` in the switch (backward-compatible) |
| `docker-compose.yml` omits the new env var — container uses code default | Use `${AUTHENTICATION_PROVIDER:-Cognito}` so the var is explicit in compose but safe to omit from `.env` |
| Developer switches to Auth0 but doesn't know what env vars to set | Auth0 block in `.env.example` is commented-out documentation — no secrets, just variable names |

---

## Success Criteria

- [ ] `dotnet build IFX.sln` — zero errors, zero warnings related to this change
- [ ] `dotnet test IFX.sln` — all 252 tests pass
- [ ] No file in `Auth.Application` or `Auth.Domain` contains `using Amazon` or `using Auth0`
- [ ] `ICognitoService` does not exist anywhere
- [ ] `CognitoSignUpResult`, `CognitoAuthResult`, `CognitoUserInfo` do not exist anywhere
- [ ] `IdentityProviders/Cognito/` contains all Cognito-specific infrastructure code
- [ ] `IdentityProviders/Auth0/` contains Auth0 stub implementations
- [ ] Setting `Authentication:Provider = Auth0` registers `Auth0IdentityProvider` and `Auth0OidcService`
- [ ] Setting `Authentication:Provider = Cognito` registers `CognitoIdentityProvider` and `CognitoOidcService`
- [ ] `docker-compose.yml` passes `Authentication__Provider` to `auth-api` with `:-Cognito` default
- [ ] `.env.example` documents `AUTHENTICATION_PROVIDER` and the Auth0 variable block
