using System.Text.Json;
using IFX.BuildingBlocks.Security.Authorization.Abac.Policies;
using IFX.BuildingBlocks.Security.Authorization.Abac.Registry;
using IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;

using IFX.Modules.Auth.Domain.Authorization;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Infrastructure.Authorization;

/// <summary>
/// Resolves ABAC policies from the database (with IMemoryCache TTL 60s),
/// falling back to the <see cref="StaticAbacPolicyResolver"/> for platform defaults.
/// </summary>
public sealed class DbAbacPolicyResolver : IAbacPolicyResolver, IAbacPolicyCache
{
    private static readonly TimeSpan CacheTtl = TimeSpan.FromSeconds(60);

    private readonly IPolicyDefinitionRepository _repository;
    private readonly IAbacTemplateRegistry _templateRegistry;
    private readonly StaticAbacPolicyResolver _staticResolver;
    private readonly IMemoryCache _cache;
    private readonly ILogger<DbAbacPolicyResolver> _logger;

    public DbAbacPolicyResolver(
        IPolicyDefinitionRepository repository,
        IAbacTemplateRegistry templateRegistry,
        StaticAbacPolicyResolver staticResolver,
        IMemoryCache cache,
        ILogger<DbAbacPolicyResolver> logger)
    {
        _repository = repository;
        _templateRegistry = templateRegistry;
        _staticResolver = staticResolver;
        _cache = cache;
        _logger = logger;
    }

    public void RegisterDefault(string resourceType, string action, AbacPolicy policy)
        => _staticResolver.RegisterDefault(resourceType, action, policy);

    public async Task<AbacPolicy?> ResolvePlatformPolicyAsync(
        string resourceType,
        string action,
        CancellationToken ct = default)
    {
        var resource = resourceType.ToLowerInvariant();
        var act = action.ToLowerInvariant();

        var platformKey = $"abac:platform:{resource}:{act}";
        if (_cache.TryGetValue(platformKey, out AbacPolicy? platformCached))
            return platformCached;

        PolicyDefinition? platformRow = null;
        try { platformRow = await _repository.GetPlatformAsync(resourceType, action, ct); }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Failed to load platform ABAC policy from DB for {ResourceType}/{Action}",
                resourceType, action);
        }

        if (platformRow is not null)
        {
            var policy = DeserializePolicy(platformRow, resource, act);
            _cache.Set(platformKey, policy, CacheTtl);
            return policy;
        }

        return await _staticResolver.ResolvePlatformPolicyAsync(resourceType, action, ct);
    }

    public async Task<AbacPolicy?> ResolvePlatformPolicyForRoleAsync(
        string resourceType,
        string action,
        string globalRole,
        CancellationToken ct = default)
    {
        var resource = resourceType.ToLowerInvariant();
        var act = action.ToLowerInvariant();

        var cacheKey = $"abac:platform:{resource}:{act}:role:{globalRole}";
        if (_cache.TryGetValue(cacheKey, out AbacPolicy? cached))
            return cached;

        PolicyDefinition? row = null;
        try { row = await _repository.GetPlatformByGlobalRoleAsync(resource, act, globalRole, ct); }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Failed to load platform ABAC policy for GlobalRole '{GlobalRole}' {ResourceType}/{Action}",
                globalRole, resourceType, action);
        }

        if (row is null)
            return null;

        var policy = DeserializePolicy(row, resource, act);
        _cache.Set(cacheKey, policy, CacheTtl);
        return policy;
    }

    public async Task<AbacPolicy?> ResolveTenantPolicyAsync(
        Guid tenantId,
        string resourceType,
        string action,
        CancellationToken ct = default)
    {
        var resource = resourceType.ToLowerInvariant();
        var act = action.ToLowerInvariant();

        // 1. Tenant-level DB row
        var tenantKey = $"abac:{tenantId}:{resource}:{act}";
        if (_cache.TryGetValue(tenantKey, out AbacPolicy? tenantCached))
            return tenantCached;

        PolicyDefinition? tenantRow = null;
        try { tenantRow = await _repository.GetAsync(tenantId, resourceType, action, ct); }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Failed to load ABAC policy from DB for tenant {TenantId} {ResourceType}/{Action}",
                tenantId, resourceType, action);
        }

        if (tenantRow is not null)
        {
            var policy = DeserializePolicy(tenantRow, resource, act);
            _cache.Set(tenantKey, policy, CacheTtl);
            return policy;
        }

        // 2. Platform-level DB row (fallback for tenant users)
        var platformKey = $"abac:platform:{resource}:{act}";
        if (_cache.TryGetValue(platformKey, out AbacPolicy? platformCached))
            return platformCached;

        PolicyDefinition? platformRow = null;
        try { platformRow = await _repository.GetPlatformAsync(resourceType, action, ct); }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Failed to load platform ABAC policy from DB for {ResourceType}/{Action}",
                resourceType, action);
        }

        if (platformRow is not null)
        {
            var policy = DeserializePolicy(platformRow, resource, act);
            _cache.Set(platformKey, policy, CacheTtl);
            return policy;
        }

        // 3. Static fallback
        return await _staticResolver.ResolveTenantPolicyAsync(tenantId, resourceType, action, ct);
    }

    /// <summary>Removes the tenant-scoped cache entry so the next resolve hits the DB.</summary>
    public void Invalidate(Guid tenantId, string resourceType, string action)
    {
        var cacheKey = $"abac:{tenantId}:{resourceType.ToLowerInvariant()}:{action.ToLowerInvariant()}";
        _cache.Remove(cacheKey);
    }

    /// <summary>Removes the platform-level cache entry so the next resolve hits the DB.</summary>
    public void InvalidatePlatform(string resourceType, string action)
    {
        var cacheKey = $"abac:platform:{resourceType.ToLowerInvariant()}:{action.ToLowerInvariant()}";
        _cache.Remove(cacheKey);
    }

    private AbacPolicy? DeserializePolicy(PolicyDefinition row, string resourceType, string action)
    {
        try
        {
            var records = JsonSerializer.Deserialize<List<PolicyConditionRecord>>(
                row.ConditionsJson,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

            if (records is null || records.Count == 0)
                return null;

            var conditions = records
                .Where(r => _templateRegistry.TryResolve(r.TemplateName, out _))
                .Select(r => new AbacCondition
                {
                    Template = _templateRegistry.Resolve(r.TemplateName),
                    Parameters = r.Parameters?.ToDictionary(kv => kv.Key, kv => (object)kv.Value)
                })
                .ToList();

            return new AbacPolicy
            {
                ResourceType = resourceType,
                Action = action,
                Conditions = conditions
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Failed to deserialize ABAC policy {PolicyId} for {ResourceType}/{Action}; falling back to null (deny)",
                row.Id, resourceType, action);
            return null;
        }
    }
}
