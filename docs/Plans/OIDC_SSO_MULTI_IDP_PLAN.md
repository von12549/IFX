# OIDC/SSO Multi-IdP Implementation Plan

## Overview
Enable the AuthSamples API to accept access tokens from multiple Identity Providers configured in the database `Idps` table, with automatic user provisioning for new SSO users.

## Requirements
1. Accept `access_token` from any enabled IdP in the `Idps` table
2. Auto-register local user when `AutoProvisionEnabled = true` and user doesn't exist
3. Keep existing Cognito password registration flow working alongside SSO

## User Decisions
- **Default role for auto-provisioned users**: SsoUser
- **Missing email claim handling**: Reject token with 401 Unauthorized
- **Existing Cognito flow**: Keep both (Cognito registration + SSO)

---

## Phase 1: IdP Configuration Service with Caching

### New Files
- `src/ApiHost/AuthSamples.ApiHost/Services/IIdpConfigurationService.cs`
- `src/ApiHost/AuthSamples.ApiHost/Services/IdpConfigurationService.cs`
- `src/ApiHost/AuthSamples.ApiHost/Services/IdpConfigurationEntry.cs`

### Implementation

**IdpConfigurationEntry.cs**
```csharp
public class IdpConfigurationEntry
{
    public Guid IdpId { get; init; }
    public string Issuer { get; init; } = string.Empty;
    public string Authority { get; init; } = string.Empty;
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
public interface IIdpConfigurationService
{
    Task<IdpConfigurationEntry?> GetByIssuerAsync(string issuer, CancellationToken ct = default);
    Task<IReadOnlyList<IdpConfigurationEntry>> GetAllEnabledAsync(CancellationToken ct = default);
    void InvalidateCache();
}
```

**IdpConfigurationService.cs**
- Inject `IServiceScopeFactory` and `IMemoryCache`
- Cache enabled IdPs for 5 minutes with sliding expiration
- Lazy-load `ConfigurationManager<OpenIdConnectConfiguration>` per IdP
- Store ConfigurationManagers in `ConcurrentDictionary<string, ConfigurationManager>`

---

## Phase 2: Dynamic JWT Bearer Events

### New File
- `src/ApiHost/AuthSamples.ApiHost/Authentication/DynamicJwtBearerEvents.cs`

### Implementation

**DynamicJwtBearerEvents.cs**
```csharp
public class DynamicJwtBearerEvents : JwtBearerEvents
{
    private readonly IIdpConfigurationService _idpConfigService;

    public override async Task MessageReceived(MessageReceivedContext context)
    {
        // 1. Extract token from Authorization header
        // 2. Read unvalidated JWT to get "iss" claim
        // 3. Look up IdP by issuer via IIdpConfigurationService
        // 4. If IdP not found or disabled, fail authentication
        // 5. Get OpenIdConnectConfiguration from ConfigurationManager
        // 6. Configure TokenValidationParameters dynamically:
        //    - ValidIssuer = idp.Issuer
        //    - ValidAudiences = idp.ExpectedAudiences
        //    - ValidAlgorithms = idp.AllowedAlgorithms
        //    - ClockSkew = TimeSpan.FromSeconds(idp.ClockSkewSeconds)
        //    - IssuerSigningKeys = openIdConfig.SigningKeys
    }

    public override Task TokenValidated(TokenValidatedContext context)
    {
        // Store IdpConfigurationEntry in HttpContext.Items for later use
        // Key: "IdpConfiguration"
    }

    public override Task AuthenticationFailed(AuthenticationFailedContext context)
    {
        // Log authentication failures with issuer info
    }
}
```

### Modify AuthenticationConfiguration.cs
```csharp
public static IServiceCollection AddAuthAuthentication(this IServiceCollection services, IConfiguration config)
{
    // Register IdpConfigurationService
    services.AddMemoryCache();
    services.AddScoped<IIdpConfigurationService, IdpConfigurationService>();
    services.AddScoped<DynamicJwtBearerEvents>();

    services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddJwtBearer(options =>
        {
            // Disable default issuer/audience validation (handled dynamically)
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = false,
                ValidateAudience = false,
                ValidateIssuerSigningKey = true,
                ValidateLifetime = true
            };

            // Use custom events for dynamic validation
            options.EventsType = typeof(DynamicJwtBearerEvents);
        });

    return services;
}
```

---

## Phase 3: User Auto-Provisioning Service

### New Files
- `src/ApiHost/AuthSamples.ApiHost/Services/IUserAutoProvisioningService.cs`
- `src/ApiHost/AuthSamples.ApiHost/Services/UserAutoProvisioningService.cs`

### Implementation

**IUserAutoProvisioningService.cs**
```csharp
public interface IUserAutoProvisioningService
{
    Task<User?> ProvisionUserAsync(
        ClaimsPrincipal principal,
        IdpConfigurationEntry idpConfig,
        CancellationToken ct = default);
}
```

**UserAutoProvisioningService.cs**
```csharp
public class UserAutoProvisioningService : IUserAutoProvisioningService
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<UserAutoProvisioningService> _logger;

    public async Task<User?> ProvisionUserAsync(
        ClaimsPrincipal principal,
        IdpConfigurationEntry idpConfig,
        CancellationToken ct = default)
    {
        // 1. Check AutoProvisionEnabled flag
        if (!idpConfig.AutoProvisionEnabled)
            return null;

        // 2. Extract claims (apply ClaimMapping if configured)
        var issuer = principal.FindFirst("iss")?.Value;
        var subject = principal.FindFirst("sub")?.Value;
        var email = principal.FindFirst("email")?.Value
                 ?? principal.FindFirst(ClaimTypes.Email)?.Value;

        // 3. Reject if no email claim (per user requirement)
        if (string.IsNullOrEmpty(email))
        {
            _logger.LogWarning("Auto-provisioning rejected: no email claim for {Issuer}/{Subject}",
                issuer, subject);
            return null; // Caller should return 401
        }

        // 4. Get SsoUser role
        var ssoUserRole = await _unitOfWork.UserRoles.GetByNameAsync("SsoUser", ct);

        // 5. Create User entity
        var firstName = principal.FindFirst("given_name")?.Value ?? "";
        var lastName = principal.FindFirst("family_name")?.Value ?? "";
        var displayName = !string.IsNullOrEmpty(firstName) || !string.IsNullOrEmpty(lastName)
            ? $"{firstName} {lastName}".Trim()
            : email;

        var user = User.Create(ssoUserRole.Id, displayName, isActive: true);
        await _unitOfWork.Users.AddAsync(user, ct);

        // 6. Create UserIdentity entity
        var userIdentity = UserIdentity.Create(
            userId: user.Id,
            idpId: idpConfig.IdpId,
            issuer: issuer,
            subject: Subject.Create(subject),
            email: EmailAddress.Create(email),
            firstName: firstName,
            lastName: lastName,
            birthDate: null,
            phoneNumber: null,
            emailVerified: principal.FindFirst("email_verified")?.Value == "true",
            phoneNumberVerified: false);

        await _unitOfWork.UserIdentities.AddAsync(userIdentity, ct);

        // 7. Log activity
        var activityLog = UserActivityLog.Create(
            user.Id,
            ActivityType.Registration,
            "User auto-provisioned via SSO",
            ipAddress: null,
            metadata: new { IdpId = idpConfig.IdpId, Issuer = issuer });
        await _unitOfWork.UserActivityLogs.AddAsync(activityLog, ct);

        await _unitOfWork.SaveChangesAsync(ct);

        _logger.LogInformation(
            "Auto-provisioned user {UserId} from {Issuer} with subject {Subject}",
            user.Id, issuer, subject);

        return user;
    }
}
```

---

## Phase 4: Integration with Claims Transformation

### Modify UserRoleClaimsTransformation.cs

```csharp
public class UserRoleClaimsTransformation : IClaimsTransformation
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IUserAutoProvisioningService _provisioningService;
    private readonly IHttpContextAccessor _httpContextAccessor;

    public async Task<ClaimsPrincipal> TransformAsync(ClaimsPrincipal principal)
    {
        var issuer = principal.FindFirst("iss")?.Value;
        var subject = principal.FindFirst("sub")?.Value;

        if (string.IsNullOrEmpty(issuer) || string.IsNullOrEmpty(subject))
            return principal;

        // Try to find existing user
        var user = await _unitOfWork.Users.GetByIssuerAndSubjectAsync(issuer, subject);

        // If not found, try auto-provisioning
        if (user == null)
        {
            var idpConfig = _httpContextAccessor.HttpContext?.Items["IdpConfiguration"]
                as IdpConfigurationEntry;

            if (idpConfig != null)
            {
                user = await _provisioningService.ProvisionUserAsync(principal, idpConfig);

                // If still null (no email or auto-provision disabled), reject
                if (user == null)
                {
                    // Return empty principal to trigger 401
                    return new ClaimsPrincipal();
                }
            }
        }

        if (user == null)
            return principal;

        // Add role claim
        var identity = principal.Identity as ClaimsIdentity;
        identity?.AddClaim(new Claim(ClaimTypes.Role, user.UserRole.RoleName));

        return principal;
    }
}
```

---

## Phase 5: Repository Enhancement

### Modify IdpRepository.cs

Add method for efficient enabled IdP lookup:

```csharp
public async Task<Idp?> GetEnabledByIssuerAsync(string issuer, CancellationToken ct = default)
{
    return await _context.Idps
        .AsNoTracking()
        .Where(i => i.Issuer == issuer && i.Enabled)
        .FirstOrDefaultAsync(ct);
}

public async Task<IReadOnlyList<Idp>> GetAllEnabledAsync(CancellationToken ct = default)
{
    return await _context.Idps
        .AsNoTracking()
        .Where(i => i.Enabled)
        .ToListAsync(ct);
}
```

---

## Phase 6: Cache Invalidation (Admin Endpoints)

### Modify IdpEndpoints.cs

Inject `IIdpConfigurationService` and call `InvalidateCache()` after:
- `POST /api/v1/idp` (CreateIdp)
- `PUT /api/v1/idp/{idpId}` (UpdateIdp)

---

## File Changes Summary

### New Files (6)
1. `src/ApiHost/AuthSamples.ApiHost/Services/IIdpConfigurationService.cs`
2. `src/ApiHost/AuthSamples.ApiHost/Services/IdpConfigurationService.cs`
3. `src/ApiHost/AuthSamples.ApiHost/Services/IdpConfigurationEntry.cs`
4. `src/ApiHost/AuthSamples.ApiHost/Authentication/DynamicJwtBearerEvents.cs`
5. `src/ApiHost/AuthSamples.ApiHost/Services/IUserAutoProvisioningService.cs`
6. `src/ApiHost/AuthSamples.ApiHost/Services/UserAutoProvisioningService.cs`

### Modified Files (4)
1. `src/ApiHost/AuthSamples.ApiHost/Configuration/AuthenticationConfiguration.cs`
2. `src/ApiHost/AuthSamples.ApiHost/Authorization/UserRoleClaimsTransformation.cs`
3. `src/Modules/Auth/AuthSamples.Modules.Auth.Infrastructure/Persistence/Repositories/IdpRepository.cs`
4. `src/Modules/Auth/AuthSamples.Modules.Auth.Presentation/Endpoints/Idp/IdpEndpoints.cs`

---

## Testing Checklist

### Unit Tests
- [ ] IdpConfigurationService caching behavior
- [ ] DynamicJwtBearerEvents issuer extraction
- [ ] UserAutoProvisioningService claim mapping
- [ ] UserAutoProvisioningService email rejection

### Integration Tests
- [ ] Token from enabled IdP accepted
- [ ] Token from disabled IdP rejected (401)
- [ ] Token from unknown issuer rejected (401)
- [ ] Auto-provisioning creates User + UserIdentity
- [ ] Auto-provisioning assigns SsoUser role
- [ ] Token without email rejected (401)
- [ ] Existing Cognito registration still works
- [ ] Cache invalidation on IdP update

### Manual Testing
1. Add new IdP to database with `Enabled = true`, `AutoProvisionEnabled = true`
2. Obtain token from that IdP
3. Call protected endpoint with token
4. Verify user created in database with SsoUser role
5. Verify subsequent requests use cached user

---

## Rollback Strategy

1. Revert `AuthenticationConfiguration.cs` to single Cognito authority
2. Remove new service files
3. Revert `UserRoleClaimsTransformation.cs` changes
4. No database migrations required (uses existing Idps table)
