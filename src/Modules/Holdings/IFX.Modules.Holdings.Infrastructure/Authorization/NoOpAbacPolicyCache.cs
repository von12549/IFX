using IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;

namespace IFX.Modules.Holdings.Infrastructure.Authorization;

/// <summary>
/// No-op ABAC policy cache for the Holdings module.
/// Holdings does not own PolicyDefinitions — policy invalidation is managed by the Auth module.
/// </summary>
public sealed class NoOpAbacPolicyCache : IAbacPolicyCache
{
    public void Invalidate(Guid tenantId, string resourceType, string action)
    {
        // No-op: Holdings module does not cache ABAC policies directly.
    }

    public void InvalidatePlatform(string resourceType, string action)
    {
        // No-op: Holdings module does not cache ABAC policies directly.
    }
}
