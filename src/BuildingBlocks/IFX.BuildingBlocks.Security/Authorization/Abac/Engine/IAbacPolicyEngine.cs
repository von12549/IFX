using IFX.BuildingBlocks.Security.Authorization.Abac.Policies;

namespace IFX.BuildingBlocks.Security.Authorization.Abac.Engine;

/// <summary>
/// Resolves an <see cref="AbacPolicy"/> into a list of <see cref="ResolvedCondition"/>s
/// ready for serialization into the OPA input envelope.
/// </summary>
public interface IAbacPolicyEngine
{
    /// <summary>
    /// Resolves all conditions in the policy.
    /// <see cref="Templates.ValueRefType.UserInput"/> references are substituted from
    /// <paramref name="parameters"/>.
    /// </summary>
    /// <param name="policy">The policy whose conditions should be resolved.</param>
    /// <param name="parameters">
    /// Runtime values for UserInput references. Key = the param key defined in the template's
    /// <see cref="Templates.ConditionValueRef.Value"/>. Required when any condition uses
    /// <see cref="Templates.ValueRefType.UserInput"/>.
    /// </param>
    /// <exception cref="ArgumentException">
    /// Thrown when a UserInput reference cannot be resolved from <paramref name="parameters"/>.
    /// </exception>
    IReadOnlyList<ResolvedCondition> Resolve(
        AbacPolicy policy,
        IDictionary<string, object>? parameters = null);
}
