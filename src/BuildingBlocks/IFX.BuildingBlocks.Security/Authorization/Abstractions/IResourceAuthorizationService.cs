using IFX.BuildingBlocks.Security.Authorization.Models;

namespace IFX.BuildingBlocks.Security.Authorization.Abstractions;

public interface IResourceAuthorizationService
{
    /// <param name="requiredPermission">
    /// Coarse-grained RBAC permission name. When null, the RBAC gate is skipped
    /// and OPA is the sole decision maker.
    /// </param>
    Task AuthorizeAsync<TResource>(
        string? requiredPermission,
        string decisionPath,
        TResource resourceAttributes,
        string action,
        CancellationToken ct = default)
        where TResource : OpaResourceAttributesBase;
}
