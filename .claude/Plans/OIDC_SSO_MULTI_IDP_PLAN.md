# OIDC/SSO Multi-IdP Implementation Plan

## Overview
Enable the IFX API to accept access tokens from multiple Identity Providers configured in the database `Idps` table, with automatic user provisioning for new SSO users.

## Requirements
1. Accept `access_token` from any enabled IdP in the `Idps` table
2. Auto-register local user when `AutoProvisionEnabled = true` and user doesn't exist
3. Keep existing Cognito password registration flow working alongside SSO

## User Decisions
- **Default role for auto-provisioned users**: Based on IdP type
  - **Internal IdP** → `User` role
  - **External IdP** → `SsoUser` role
- **Missing email claim handling**: Reject token with 401 Unauthorized
- **Existing Cognito flow**: Keep both (Cognito registration + SSO)

---

## Prerequisite: IdpType Column Migration

A new `IdpType` column has been added to the `Idps` table to distinguish between Internal and External identity providers.

**Migration:** `20260114025631_AddIdpTypeColumn`

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `IdpType` | `nvarchar(20)` | `"Internal"` | `Internal` or `External` |

**Role Assignment Rules:**
- **Internal IdP** → Auto-provisioned users get `User` role
- **External IdP** → Auto-provisioned users get `SsoUser` role

All existing IdP records are automatically set to `Internal` via the migration default value.

---

## Architecture Alignment

This plan follows the project's Clean Architecture + CQRS patterns:

| Component | Layer | Rationale |
|-----------|-------|-----------|
| `IdpConfigurationService` | ApiHost | Cross-cutting auth concern |
| `DynamicJwtBearerEvents` | ApiHost | ASP.NET Core auth middleware |
| `ProvisionSsoUserCommand` | Auth.Application | Business logic via CQRS |
| Repository enhancements | Auth.Domain/Infrastructure | Data access |

---

## Phase 1: IdP Configuration Service (ApiHost - Cross-cutting)

### New Files
- `src/ApiHost/IFX.ApiHost/Authentication/IdpConfigurationEntry.cs`
- `src/ApiHost/IFX.ApiHost/Authentication/IIdpConfigurationService.cs`
- `src/ApiHost/IFX.ApiHost/Authentication/IdpConfigurationService.cs`

### Implementation

**IdpConfigurationEntry.cs**
```csharp
using IFX.Modules.Auth.Domain.Enums;

namespace IFX.ApiHost.Authentication;

public class IdpConfigurationEntry
{
    public Guid IdpId { get; init; }
    public string Issuer { get; init; } = string.Empty;
    public string Authority { get; init; } = string.Empty;
    public IdpType IdpType { get; init; }
    public bool AutoProvisionEnabled { get; init; }
    public List<string> ExpectedAudiences { get; init; } = new();
    public List<string> AllowedAlgorithms { get; init; } = new();
    public int ClockSkewSeconds { get; init; }
    public Dictionary<string, string> ClaimMapping { get; init; } = new();
    public ConfigurationManager<OpenIdConnectConfiguration>? ConfigurationManager { get; set; }
}
```

**IIdpConfigurationService.cs**
```csharp
namespace IFX.ApiHost.Authentication;

public interface IIdpConfigurationService
{
    Task<IdpConfigurationEntry?> GetByIssuerAsync(string issuer, CancellationToken ct = default);
    Task<IReadOnlyList<IdpConfigurationEntry>> GetAllEnabledAsync(CancellationToken ct = default);
    void InvalidateCache();
}
```

**IdpConfigurationService.cs**
```csharp
namespace IFX.ApiHost.Authentication;

public class IdpConfigurationService : IIdpConfigurationService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly IMemoryCache _cache;
    private readonly ConcurrentDictionary<string, ConfigurationManager<OpenIdConnectConfiguration>> _configManagers = new();
    private const string CacheKey = "EnabledIdpConfigurations";
    private static readonly TimeSpan CacheDuration = TimeSpan.FromMinutes(5);

    public IdpConfigurationService(IServiceScopeFactory scopeFactory, IMemoryCache cache)
    {
        _scopeFactory = scopeFactory;
        _cache = cache;
    }

    public async Task<IdpConfigurationEntry?> GetByIssuerAsync(string issuer, CancellationToken ct = default)
    {
        var all = await GetAllEnabledAsync(ct);
        var entry = all.FirstOrDefault(x => x.Issuer == issuer);

        if (entry != null)
        {
            entry.ConfigurationManager = GetOrCreateConfigurationManager(entry);
        }

        return entry;
    }

    public async Task<IReadOnlyList<IdpConfigurationEntry>> GetAllEnabledAsync(CancellationToken ct = default)
    {
        if (_cache.TryGetValue(CacheKey, out IReadOnlyList<IdpConfigurationEntry>? cached) && cached != null)
            return cached;

        using var scope = _scopeFactory.CreateScope();
        var unitOfWork = scope.ServiceProvider.GetRequiredService<IUnitOfWork>();
        var idps = await unitOfWork.Idps.GetEnabledAsync(ct);

        var entries = idps.Select(idp => new IdpConfigurationEntry
        {
            IdpId = idp.Id,
            Issuer = idp.Issuer,
            Authority = idp.Authority,
            IdpType = idp.IdpType,
            AutoProvisionEnabled = idp.AutoProvisionEnabled,
            ExpectedAudiences = idp.ExpectedAudiences,
            AllowedAlgorithms = idp.AllowedAlgorithms,
            ClockSkewSeconds = idp.ClockSkewSeconds,
            ClaimMapping = idp.ClaimMapping
        }).ToList();

        _cache.Set(CacheKey, (IReadOnlyList<IdpConfigurationEntry>)entries,
            new MemoryCacheEntryOptions().SetSlidingExpiration(CacheDuration));

        return entries;
    }

    public void InvalidateCache()
    {
        _cache.Remove(CacheKey);
    }

    private ConfigurationManager<OpenIdConnectConfiguration> GetOrCreateConfigurationManager(IdpConfigurationEntry entry)
    {
        return _configManagers.GetOrAdd(entry.Issuer, _ =>
            new ConfigurationManager<OpenIdConnectConfiguration>(
                $"{entry.Authority}/.well-known/openid-configuration",
                new OpenIdConnectConfigurationRetriever(),
                new HttpDocumentRetriever()));
    }
}
```

---

## Phase 2: Dynamic JWT Bearer Events (ApiHost - Cross-cutting)

### New File
- `src/ApiHost/IFX.ApiHost/Authentication/DynamicJwtBearerEvents.cs`

### Implementation

**DynamicJwtBearerEvents.cs**
```csharp
namespace IFX.ApiHost.Authentication;

public class DynamicJwtBearerEvents : JwtBearerEvents
{
    private readonly IIdpConfigurationService _idpConfigService;
    private readonly ILogger<DynamicJwtBearerEvents> _logger;

    public DynamicJwtBearerEvents(
        IIdpConfigurationService idpConfigService,
        ILogger<DynamicJwtBearerEvents> logger)
    {
        _idpConfigService = idpConfigService;
        _logger = logger;
    }

    public override async Task MessageReceived(MessageReceivedContext context)
    {
        var token = context.Request.Headers.Authorization.FirstOrDefault()?.Replace("Bearer ", "");
        if (string.IsNullOrEmpty(token))
            return;

        try
        {
            // Read unvalidated JWT to get issuer
            var handler = new JwtSecurityTokenHandler();
            var jwtToken = handler.ReadJwtToken(token);
            var issuer = jwtToken.Issuer;

            // Look up IdP by issuer
            var idpConfig = await _idpConfigService.GetByIssuerAsync(issuer, context.HttpContext.RequestAborted);
            if (idpConfig == null)
            {
                _logger.LogWarning("Token from unknown or disabled issuer: {Issuer}", issuer);
                context.Fail("Unknown or disabled identity provider");
                return;
            }

            // Get OIDC configuration
            var openIdConfig = await idpConfig.ConfigurationManager!.GetConfigurationAsync(context.HttpContext.RequestAborted);

            // Configure dynamic validation parameters
            context.Options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidIssuer = idpConfig.Issuer,
                ValidateAudience = idpConfig.ExpectedAudiences.Any(),
                ValidAudiences = idpConfig.ExpectedAudiences,
                ValidAlgorithms = idpConfig.AllowedAlgorithms.Any() ? idpConfig.AllowedAlgorithms : null,
                ClockSkew = TimeSpan.FromSeconds(idpConfig.ClockSkewSeconds),
                ValidateIssuerSigningKey = true,
                IssuerSigningKeys = openIdConfig.SigningKeys,
                ValidateLifetime = true
            };

            // Store IdP config for later use in claims transformation
            context.HttpContext.Items["IdpConfiguration"] = idpConfig;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing JWT token");
            context.Fail("Invalid token format");
        }
    }

    public override Task TokenValidated(TokenValidatedContext context)
    {
        var issuer = context.Principal?.FindFirst("iss")?.Value;
        var subject = context.Principal?.FindFirst("sub")?.Value;
        _logger.LogDebug("Token validated for {Issuer}/{Subject}", issuer, subject);
        return Task.CompletedTask;
    }

    public override Task AuthenticationFailed(AuthenticationFailedContext context)
    {
        _logger.LogWarning(context.Exception, "Authentication failed");
        return Task.CompletedTask;
    }
}
```

---

## Phase 3: SSO User Provisioning Command (Auth.Application - CQRS)

### New Files
- `src/Modules/Auth/IFX.Modules.Auth.Application/Commands/ProvisionSsoUser/ProvisionSsoUserCommand.cs`
- `src/Modules/Auth/IFX.Modules.Auth.Application/Commands/ProvisionSsoUser/ProvisionSsoUserCommandHandler.cs`
- `src/Modules/Auth/IFX.Modules.Auth.Application/Commands/ProvisionSsoUser/ProvisionSsoUserCommandValidator.cs`
- `src/Modules/Auth/IFX.Modules.Auth.Application/DTOs/ProvisionSsoUserResponse.cs`

### Implementation

**ProvisionSsoUserCommand.cs**
```csharp
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using IFX.Modules.Auth.Domain.Enums;
using MediatR;

namespace IFX.Modules.Auth.Application.Commands.ProvisionSsoUser;

public record ProvisionSsoUserCommand(
    Guid IdpId,
    string Issuer,
    string Subject,
    IdpType IdpType,
    string? Email,
    string? FirstName,
    string? LastName,
    bool EmailVerified,
    string? IpAddress) : IRequest<Result<ProvisionSsoUserResponse>>;
```

**ProvisionSsoUserResponse.cs**
```csharp
namespace IFX.Modules.Auth.Application.DTOs;

public record ProvisionSsoUserResponse
{
    public Guid UserId { get; init; }
    public string RoleName { get; init; } = string.Empty;
    public bool WasProvisioned { get; init; }
}
```

**ProvisionSsoUserCommandValidator.cs**
```csharp
using FluentValidation;

namespace IFX.Modules.Auth.Application.Commands.ProvisionSsoUser;

public class ProvisionSsoUserCommandValidator : AbstractValidator<ProvisionSsoUserCommand>
{
    public ProvisionSsoUserCommandValidator()
    {
        RuleFor(x => x.IdpId).NotEmpty();
        RuleFor(x => x.Issuer).NotEmpty();
        RuleFor(x => x.Subject).NotEmpty();
        RuleFor(x => x.Email).NotEmpty()
            .WithMessage("Email claim is required for SSO user provisioning");
    }
}
```

**ProvisionSsoUserCommandHandler.cs**
```csharp
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Entities;
using IFX.Modules.Auth.Domain.Enums;
using IFX.Modules.Auth.Domain.ValueObjects;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Commands.ProvisionSsoUser;

public class ProvisionSsoUserCommandHandler : IRequestHandler<ProvisionSsoUserCommand, Result<ProvisionSsoUserResponse>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<ProvisionSsoUserCommandHandler> _logger;

    public ProvisionSsoUserCommandHandler(
        IUnitOfWork unitOfWork,
        ILogger<ProvisionSsoUserCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<ProvisionSsoUserResponse>> Handle(
        ProvisionSsoUserCommand request,
        CancellationToken cancellationToken)
    {
        try
        {
            // Check if user already exists by issuer/subject
            var existingUser = await _unitOfWork.Users.GetByIssuerAndSubjectAsync(
                request.Issuer, request.Subject, cancellationToken);

            if (existingUser != null)
            {
                var existingRole = await _unitOfWork.UserRoles.GetByIdAsync(
                    existingUser.UserRoleId, cancellationToken);

                return Result<ProvisionSsoUserResponse>.Success(new ProvisionSsoUserResponse
                {
                    UserId = existingUser.Id,
                    RoleName = existingRole?.RoleName ?? "Unknown",
                    WasProvisioned = false
                });
            }

            // Determine role based on IdP type:
            // - Internal IdP → "User" role
            // - External IdP → "SsoUser" role
            var roleName = request.IdpType == IdpType.Internal ? "User" : "SsoUser";
            var userRole = await _unitOfWork.UserRoles.GetByRoleNameAsync(roleName, cancellationToken);
            if (userRole == null)
            {
                _logger.LogError("'{RoleName}' role not found in database", roleName);
                return Result<ProvisionSsoUserResponse>.Failure(
                    "System configuration error. Please contact support.");
            }

            // Create display name
            var displayName = !string.IsNullOrEmpty(request.FirstName) || !string.IsNullOrEmpty(request.LastName)
                ? $"{request.FirstName} {request.LastName}".Trim()
                : request.Email!;

            // Create User entity
            var user = User.Create(
                userRoleId: userRole.Id,
                displayName: displayName,
                isActive: true); // SSO users are active immediately

            await _unitOfWork.Users.AddAsync(user, cancellationToken);

            // Create UserIdentity entity
            var userIdentity = UserIdentity.Create(
                userId: user.Id,
                idpId: request.IdpId,
                issuer: request.Issuer,
                subject: Subject.Create(request.Subject),
                email: EmailAddress.Create(request.Email!),
                firstName: request.FirstName ?? string.Empty,
                lastName: request.LastName ?? string.Empty,
                birthDate: null,
                phoneNumber: null,
                emailVerified: request.EmailVerified,
                phoneNumberVerified: false);

            await _unitOfWork.UserIdentities.AddAsync(userIdentity, cancellationToken);

            // Create UserActivityLog
            var activityLog = UserActivityLog.Create(
                user.Id,
                ActivityType.Registration,
                $"User auto-provisioned via SSO from {request.Issuer} (IdpType: {request.IdpType})",
                request.IpAddress);

            await _unitOfWork.UserActivityLogs.AddAsync(activityLog, cancellationToken);

            // Save changes
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "Auto-provisioned SSO user {UserId} from {Issuer} with subject {Subject}, assigned role {RoleName}",
                user.Id, request.Issuer, request.Subject, userRole.RoleName);

            return Result<ProvisionSsoUserResponse>.Success(new ProvisionSsoUserResponse
            {
                UserId = user.Id,
                RoleName = userRole.RoleName,
                WasProvisioned = true
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error provisioning SSO user from {Issuer}", request.Issuer);
            return Result<ProvisionSsoUserResponse>.Failure("An error occurred during SSO user provisioning");
        }
    }
}
```

---

## Phase 4: Claims Transformation Integration (ApiHost)

### Modify UserRoleClaimsTransformation.cs

```csharp
public class UserRoleClaimsTransformation : IClaimsTransformation
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMediator _mediator;
    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly ILogger<UserRoleClaimsTransformation> _logger;

    public UserRoleClaimsTransformation(
        IUnitOfWork unitOfWork,
        IMediator mediator,
        IHttpContextAccessor httpContextAccessor,
        ILogger<UserRoleClaimsTransformation> logger)
    {
        _unitOfWork = unitOfWork;
        _mediator = mediator;
        _httpContextAccessor = httpContextAccessor;
        _logger = logger;
    }

    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        var issuer = principal.FindFirst("iss")?.Value;
        var subject = principal.FindFirst("sub")?.Value;

        if (string.IsNullOrEmpty(issuer) || string.IsNullOrEmpty(subject))
            return principal;

        // Try to find existing user
        var user = await _unitOfWork.Users.GetByIssuerAndSubjectAsync(issuer, subject);

        // If not found, try auto-provisioning via CQRS command
        if (user == null)
        {
            var idpConfig = _httpContextAccessor.HttpContext?.Items["IdpConfiguration"]
                as IdpConfigurationEntry;

            if (idpConfig?.AutoProvisionEnabled == true)
            {
                var email = principal.FindFirst("email")?.Value
                         ?? principal.FindFirst(ClaimTypes.Email)?.Value;

                if (string.IsNullOrEmpty(email))
                {
                    _logger.LogWarning(
                        "SSO user from {Issuer}/{Subject} rejected: missing email claim",
                        issuer, subject);
                    return new ClaimsPrincipal(); // Return empty principal to trigger 401
                }

                var command = new ProvisionSsoUserCommand(
                    IdpId: idpConfig.IdpId,
                    Issuer: issuer,
                    Subject: subject,
                    IdpType: idpConfig.IdpType,
                    Email: email,
                    FirstName: principal.FindFirst("given_name")?.Value,
                    LastName: principal.FindFirst("family_name")?.Value,
                    EmailVerified: principal.FindFirst("email_verified")?.Value == "true",
                    IpAddress: _httpContextAccessor.HttpContext?.Connection.RemoteIpAddress?.ToString());

                var result = await _mediator.Send(command);

                if (!result.IsSuccess)
                {
                    _logger.LogWarning("SSO user provisioning failed: {Error}", result.ErrorMessage);
                    return new ClaimsPrincipal();
                }

                // Add role claim from provisioning result
                var identity = principal.Identity as ClaimsIdentity;
                identity?.AddClaim(new Claim(ClaimTypes.Role, result.Value!.RoleName));
                identity?.AddClaim(new Claim("user_id", result.Value.UserId.ToString()));

                return principal;
            }
        }

        if (user == null)
            return principal;

        // Add role claim for existing user
        var role = await _unitOfWork.UserRoles.GetByIdAsync(user.UserRoleId);
        var claimsIdentity = principal.Identity as ClaimsIdentity;
        claimsIdentity?.AddClaim(new Claim(ClaimTypes.Role, role?.RoleName ?? "User"));
        claimsIdentity?.AddClaim(new Claim("user_id", user.Id.ToString()));

        return principal;
    }
}
```

---

## Phase 5: Repository Enhancement (Auth.Domain/Infrastructure)

### Modify IIdpRepository.cs (Domain)

Add method for enabled IdP lookup by issuer:

```csharp
Task<Idp?> GetEnabledByIssuerAsync(string issuer, CancellationToken cancellationToken = default);
```

### Modify IdpRepository.cs (Infrastructure)

```csharp
public async Task<Idp?> GetEnabledByIssuerAsync(string issuer, CancellationToken ct = default)
{
    return await _context.Idps
        .AsNoTracking()
        .Where(i => i.Issuer == issuer && i.Enabled)
        .FirstOrDefaultAsync(ct);
}
```

---

## Phase 6: DI Registration & Cache Invalidation

### Modify AuthenticationConfiguration.cs

```csharp
public static IServiceCollection AddAuthAuthentication(this IServiceCollection services, IConfiguration config)
{
    // Register IdpConfigurationService (cross-cutting)
    services.AddMemoryCache();
    services.AddSingleton<IIdpConfigurationService, IdpConfigurationService>();
    services.AddScoped<DynamicJwtBearerEvents>();

    services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddJwtBearer(options =>
        {
            // Disable default validation (handled dynamically in events)
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = false,
                ValidateAudience = false,
                ValidateIssuerSigningKey = true,
                ValidateLifetime = true
            };

            options.EventsType = typeof(DynamicJwtBearerEvents);
        });

    return services;
}
```

### Modify IdpEndpoints.cs (Presentation)

Inject `IIdpConfigurationService` and invalidate cache after mutations:

```csharp
// In CreateIdp endpoint
idpConfigService.InvalidateCache();

// In UpdateIdp endpoint
idpConfigService.InvalidateCache();
```

---

## File Changes Summary

### New Files (7)
| File | Layer | Purpose |
|------|-------|---------|
| `ApiHost/Authentication/IdpConfigurationEntry.cs` | ApiHost | DTO for cached IdP config |
| `ApiHost/Authentication/IIdpConfigurationService.cs` | ApiHost | Interface for IdP config cache |
| `ApiHost/Authentication/IdpConfigurationService.cs` | ApiHost | IdP config caching implementation |
| `ApiHost/Authentication/DynamicJwtBearerEvents.cs` | ApiHost | Dynamic JWT validation |
| `Auth.Application/Commands/ProvisionSsoUser/ProvisionSsoUserCommand.cs` | Application | CQRS command |
| `Auth.Application/Commands/ProvisionSsoUser/ProvisionSsoUserCommandHandler.cs` | Application | CQRS handler |
| `Auth.Application/Commands/ProvisionSsoUser/ProvisionSsoUserCommandValidator.cs` | Application | Validation |
| `Auth.Application/DTOs/ProvisionSsoUserResponse.cs` | Application | Response DTO |

### Modified Files (4)
| File | Layer | Changes |
|------|-------|---------|
| `ApiHost/Configuration/AuthenticationConfiguration.cs` | ApiHost | Register new services |
| `ApiHost/Authorization/UserRoleClaimsTransformation.cs` | ApiHost | Add auto-provisioning via MediatR |
| `Auth.Domain/Interfaces/Repositories/IIdpRepository.cs` | Domain | Add `GetEnabledByIssuerAsync` |
| `Auth.Infrastructure/Persistence/Repositories/IdpRepository.cs` | Infrastructure | Implement new method |
| `Auth.Presentation/Endpoints/Idp/IdpEndpoints.cs` | Presentation | Cache invalidation |

---

## Testing Checklist

### Unit Tests
- [ ] IdpConfigurationService caching behavior
- [ ] DynamicJwtBearerEvents issuer extraction
- [ ] ProvisionSsoUserCommandHandler creates User + UserIdentity
- [ ] ProvisionSsoUserCommandHandler assigns "User" role for Internal IdP
- [ ] ProvisionSsoUserCommandHandler assigns "SsoUser" role for External IdP
- [ ] ProvisionSsoUserCommandValidator rejects missing email

### Integration Tests
- [ ] Token from enabled IdP accepted
- [ ] Token from disabled IdP rejected (401)
- [ ] Token from unknown issuer rejected (401)
- [ ] Auto-provisioning via ProvisionSsoUserCommand works
- [ ] Internal IdP auto-provision assigns "User" role
- [ ] External IdP auto-provision assigns "SsoUser" role
- [ ] Token without email rejected (401)
- [ ] Existing Cognito registration still works
- [ ] Cache invalidation on IdP create/update

### Manual Testing
1. Add Internal IdP: `Enabled = true`, `AutoProvisionEnabled = true`, `IdpType = Internal`
2. Add External IdP: `Enabled = true`, `AutoProvisionEnabled = true`, `IdpType = External`
3. Obtain token from Internal IdP → Verify user gets "User" role
4. Obtain token from External IdP → Verify user gets "SsoUser" role
5. Verify subsequent requests use existing user

---

## Rollback Strategy

1. Revert `AuthenticationConfiguration.cs` to single Cognito authority
2. Remove new ApiHost authentication files
3. Remove `ProvisionSsoUser` command files
4. Revert `UserRoleClaimsTransformation.cs` changes
5. No database migrations required (uses existing Idps table)
