using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Infrastructure.Persistence;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace IFX.Modules.Auth.Infrastructure.Authorization;

/// <summary>
/// Reads the current user's identity and permissions from the ClaimsPrincipal.
/// Permission and user_id claims are injected per-request by UserPermissionClaimsTransformation.
/// tenant_id is added by the same transformation after provisioning.
/// GlobalRoles are loaded lazily from DB (per-request) with a 5-minute cross-request cache.
/// </summary>
public class CurrentUser : ICurrentUser
{
    private static readonly TimeSpan GlobalRolesCacheTtl = TimeSpan.FromMinutes(5);

    private readonly IHttpContextAccessor _httpContextAccessor;
    private readonly IfxDbContext _dbContext;
    private readonly IMemoryCache _cache;

    private IReadOnlyList<string>? _globalRoles;

    public CurrentUser(
        IHttpContextAccessor httpContextAccessor,
        IfxDbContext dbContext,
        IMemoryCache cache)
    {
        _httpContextAccessor = httpContextAccessor;
        _dbContext = dbContext;
        _cache = cache;
    }

    private System.Security.Claims.ClaimsPrincipal? Principal =>
        _httpContextAccessor.HttpContext?.User;

    public bool IsAuthenticated =>
        Principal?.Identity?.IsAuthenticated == true;

    public Guid UserId
    {
        get
        {
            var value = Principal?.FindFirst("user_id")?.Value;
            return Guid.TryParse(value, out var id) ? id : Guid.Empty;
        }
    }

    public Guid? TenantId
    {
        get
        {
            // Prefer X-Tenant-Id header (tenant switcher selection), validated against user's tenant memberships
            var headerValue = _httpContextAccessor.HttpContext?.Request.Headers["X-Tenant-Id"].FirstOrDefault();
            if (Guid.TryParse(headerValue, out var headerId))
            {
                var allowedTenants = Principal?.FindAll("tenant").Select(c => c.Value).ToHashSet() ?? [];
                if (allowedTenants.Contains(headerId.ToString()))
                    return headerId;
            }

            // Fall back to primary tenant from JWT claims
            var claimValue = Principal?.FindFirst("tenant_id")?.Value;
            return Guid.TryParse(claimValue, out var id) ? id : null;
        }
    }

    public IReadOnlyCollection<string> Departments =>
        Principal?.FindAll("department").Select(c => c.Value).ToList() ?? [];

    public IReadOnlyCollection<string> Roles =>
        Principal?.FindAll(System.Security.Claims.ClaimTypes.Role)
            .Concat(Principal.FindAll("role"))
            .Select(c => c.Value)
            .Distinct()
            .ToList() ?? [];

    public IReadOnlyCollection<string> Permissions =>
        Principal?.FindAll("permission").Select(c => c.Value).ToList() ?? [];

    public bool MfaEnabled
    {
        get
        {
            // Check AMR (Authentication Methods References) claim for MFA indicators
            var amr = Principal?.FindAll("amr").Select(c => c.Value).ToList() ?? [];
            return amr.Contains("mfa") || amr.Contains("otp") || amr.Contains("hwk");
        }
    }

    public IReadOnlyList<string> GlobalRoles
    {
        get
        {
            if (_globalRoles is not null)
                return _globalRoles;

            var userId = UserId;
            if (userId == Guid.Empty)
                return _globalRoles = [];

            var cacheKey = $"globalroles:{userId}";
            if (!_cache.TryGetValue(cacheKey, out IReadOnlyList<string>? cached))
            {
                cached = _dbContext.Set<UserGlobalRole>()
                    .Where(ugr => ugr.UserId == userId)
                    .Join(
                        _dbContext.Set<GlobalRole>(),
                        ugr => ugr.GlobalRoleId,
                        gr => gr.Id,
                        (_, gr) => gr.Name)
                    .ToList();

                _cache.Set(cacheKey, cached, GlobalRolesCacheTtl);
            }

            return _globalRoles = cached ?? [];
        }
    }

    public bool IsGlobalAdmin =>
        GlobalRoles.Contains(GlobalRoleNames.PlatformAdmin);
}
