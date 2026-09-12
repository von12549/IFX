using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Modules.IAM.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace IFX.Modules.IAM.Infrastructure.Access;

/// <summary>
/// Composes the current user's request facts and persisted global roles.
/// Identity and tenant facts are supplied by dedicated outer adapters.
/// GlobalRoles are loaded lazily from DB (per-request) with a 5-minute cross-request cache.
/// </summary>
public class CurrentUser : ICurrentUser
{
    private static readonly TimeSpan GlobalRolesCacheTtl = TimeSpan.FromMinutes(5);

    private readonly HttpIdentityFacts _identityFacts;
    private readonly ExecutionTenantSelection _tenantSelection;
    private readonly IfxDbContext _dbContext;
    private readonly IMemoryCache _cache;

    private IReadOnlyList<string>? _globalRoles;

    public CurrentUser(
        HttpIdentityFacts identityFacts,
        ExecutionTenantSelection tenantSelection,
        IfxDbContext dbContext,
        IMemoryCache cache)
    {
        _identityFacts = identityFacts;
        _tenantSelection = tenantSelection;
        _dbContext = dbContext;
        _cache = cache;
    }

    public bool IsAuthenticated => _identityFacts.IsAuthenticated;

    public Guid UserId
    {
        get
        {
            return _identityFacts.UserId;
        }
    }

    public Guid? TenantId
    {
        get
        {
            return _tenantSelection.ResolveTenantId();
        }
    }

    public IReadOnlyCollection<string> Departments => _identityFacts.Departments;

    public IReadOnlyCollection<string> Roles => _identityFacts.Roles;

    public IReadOnlyCollection<string> Permissions => _identityFacts.Permissions;

    public bool MfaEnabled
    {
        get => _identityFacts.MfaEnabled;
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
