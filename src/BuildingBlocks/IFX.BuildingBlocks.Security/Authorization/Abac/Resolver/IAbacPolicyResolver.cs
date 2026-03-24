using IFX.BuildingBlocks.Security.Authorization.Abac.Policies;

namespace IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;

/// <summary>
/// Resolves an <see cref="AbacPolicy"/> for a given tenant, resource type, and action.
/// Implementations may load policies from a database (with cache), falling back to
/// static platform defaults registered via <see cref="Register"/>.
/// </summary>
public interface IAbacPolicyResolver
{
    /// <summary>
    /// Returns the policy for the given context, or <c>null</c> if none is defined.
    /// A null result should be treated as an implicit deny by the caller.
    /// </summary>
    Task<AbacPolicy?> ResolveAsync(
        Guid? tenantId,
        string resourceType,
        string action,
        CancellationToken ct = default);

    /// <summary>
    /// Registers a static platform-default policy used as fallback when no tenant
    /// override exists in the database.
    /// </summary>
    void RegisterDefault(string resourceType, string action, AbacPolicy policy);
}
