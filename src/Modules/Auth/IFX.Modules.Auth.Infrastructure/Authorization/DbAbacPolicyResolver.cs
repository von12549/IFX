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

    public async Task<AbacPolicy?> ResolveAsync(
        Guid? tenantId,
        string resourceType,
        string action,
        CancellationToken ct = default)
    {
        if (tenantId is null)
            return await _staticResolver.ResolveAsync(null, resourceType, action, ct);

        var cacheKey = $"abac:{tenantId}:{resourceType.ToLowerInvariant()}:{action.ToLowerInvariant()}";

        if (_cache.TryGetValue(cacheKey, out AbacPolicy? cached))
            return cached;

        PolicyDefinition? row = null;
        try
        {
            row = await _repository.GetAsync(tenantId.Value, resourceType, action, ct);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Failed to load ABAC policy from DB for tenant {TenantId} {ResourceType}/{Action}; falling back to static default",
                tenantId, resourceType, action);
        }

        AbacPolicy? policy;

        if (row is not null)
        {
            policy = DeserializePolicy(row, resourceType, action);
        }
        else
        {
            policy = await _staticResolver.ResolveAsync(tenantId, resourceType, action, ct);
        }

        _cache.Set(cacheKey, policy, CacheTtl);
        return policy;
    }

    /// <summary>Removes the cache entry so the next resolve hits the DB.</summary>
    public void Invalidate(Guid tenantId, string resourceType, string action)
    {
        var cacheKey = $"abac:{tenantId}:{resourceType.ToLowerInvariant()}:{action.ToLowerInvariant()}";
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
