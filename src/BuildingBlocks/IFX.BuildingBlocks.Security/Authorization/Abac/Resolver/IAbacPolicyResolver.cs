using IFX.BuildingBlocks.Security.Authorization.Abac.Policies;

namespace IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;

/// <summary>
/// Resolves an <see cref="AbacPolicy"/> for a given resource type and action.
/// Two explicit resolution paths exist: platform-scope (for global-role users) and
/// tenant-scope (for regular tenant users). Implementations use a 3-tier chain:
/// tenant/platform DB row → static fallback → null (implicit deny).
/// </summary>
public interface IAbacPolicyResolver
{
    /// <summary>
    /// Resolves a Platform-scoped policy (for global-role users).
    /// Returns <c>null</c> if no platform policy is defined — treat as implicit deny.
    /// </summary>
    Task<AbacPolicy?> ResolvePlatformPolicyAsync(
        string resourceType,
        string action,
        CancellationToken ct = default);

    /// <summary>
    /// Resolves the Platform-scoped policy whose conditions target a specific GlobalRole
    /// (e.g. "PlatformSupport" or "PlatformAuditor"). Used when multiple platform policies
    /// exist for the same resource/action. Returns <c>null</c> if none found.
    /// </summary>
    Task<AbacPolicy?> ResolvePlatformPolicyForRoleAsync(
        string resourceType,
        string action,
        string globalRole,
        CancellationToken ct = default);

    /// <summary>
    /// Resolves a Tenant-scoped policy, falling back to platform default if no tenant
    /// override exists. Returns <c>null</c> if no policy is defined — treat as implicit deny.
    /// </summary>
    Task<AbacPolicy?> ResolveTenantPolicyAsync(
        Guid tenantId,
        string resourceType,
        string action,
        CancellationToken ct = default);

    /// <summary>
    /// Registers a static platform-default policy used as fallback when no DB row exists.
    /// </summary>
    void RegisterDefault(string resourceType, string action, AbacPolicy policy);
}
