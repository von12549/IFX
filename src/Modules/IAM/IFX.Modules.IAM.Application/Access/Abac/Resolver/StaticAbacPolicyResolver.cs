using System.Collections.Concurrent;
using IFX.Modules.IAM.Application.Access.Abac.Policies;

namespace IFX.Modules.IAM.Application.Access.Abac.Resolver;

/// <summary>
/// Fallback implementation of <see cref="IAbacPolicyResolver"/> that resolves policies
/// from a static in-memory registry populated at DI startup.
/// <para>
/// The DB-backed resolver (<c>DbAbacPolicyResolver</c> in Auth.Infrastructure) wraps this
/// as the fallback: DB row → StaticAbacPolicyResolver → null (implicit deny).
/// </para>
/// </summary>
public sealed class StaticAbacPolicyResolver : IAbacPolicyResolver
{
    private readonly ConcurrentDictionary<string, AbacPolicy> _defaults = new(StringComparer.OrdinalIgnoreCase);

    public void RegisterDefault(string resourceType, string action, AbacPolicy policy)
    {
        var key = MakeKey(resourceType, action);
        _defaults[key] = policy;
    }

    public Task<AbacPolicy?> ResolvePlatformPolicyAsync(
        string resourceType,
        string action,
        CancellationToken ct = default)
    {
        _defaults.TryGetValue(MakeKey(resourceType, action), out var policy);
        return Task.FromResult(policy);
    }

    // Static resolver has no GlobalRole-specific policies — always returns null.
    public Task<AbacPolicy?> ResolvePlatformPolicyForRoleAsync(
        string resourceType,
        string action,
        string globalRole,
        CancellationToken ct = default)
        => Task.FromResult<AbacPolicy?>(null);

    public Task<AbacPolicy?> ResolveTenantPolicyAsync(
        Guid tenantId,
        string resourceType,
        string action,
        CancellationToken ct = default)
    {
        // Static resolver has no tenant concept — delegates to same in-memory lookup
        _defaults.TryGetValue(MakeKey(resourceType, action), out var policy);
        return Task.FromResult(policy);
    }

    private static string MakeKey(string resourceType, string action) =>
        $"{resourceType.Trim().ToLowerInvariant()}:{action.Trim().ToLowerInvariant()}";
}
