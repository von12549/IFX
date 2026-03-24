using IFX.BuildingBlocks.Security.Authorization.Abac.Policies;
using IFX.BuildingBlocks.Security.Authorization.Models;

namespace IFX.BuildingBlocks.Security.Authorization.Abstractions;

public interface IResourceAuthorizationService
{
    /// <summary>
    /// Coarse-grained RBAC gate followed by a resource-specific OPA policy evaluation.
    /// </summary>
    /// <param name="requiredPermission">
    /// RBAC permission name. When null, the RBAC gate is skipped and OPA is the sole decision maker.
    /// </param>
    /// <param name="decisionPath">OPA policy path (e.g. "authz/auth/read_user").</param>
    Task AuthorizeAsync<TResource>(
        string? requiredPermission,
        string decisionPath,
        TResource resourceAttributes,
        string action,
        CancellationToken ct = default)
        where TResource : OpaResourceAttributesBase;

    /// <summary>
    /// Template-based ABAC authorization. Resolves the conditions in <paramref name="policy"/>
    /// and evaluates them against the generic <c>authz/common/abac_eval</c> OPA policy.
    /// RBAC gate is skipped — combine with <see cref="AuthorizeAsync{TResource}"/> if RBAC is also needed.
    /// </summary>
    /// <param name="policy">Conditions to evaluate.</param>
    /// <param name="resourceAttributes">Resource attributes sent in the OPA input envelope.</param>
    /// <param name="parameters">
    /// Runtime values for <see cref="Templates.ValueRefType.UserInput"/> references.
    /// Required when the policy contains UserInput conditions.
    /// </param>
    Task AuthorizeWithPolicyAsync<TResource>(
        AbacPolicy policy,
        TResource resourceAttributes,
        IDictionary<string, object>? parameters = null,
        CancellationToken ct = default)
        where TResource : OpaResourceAttributesBase;
}
