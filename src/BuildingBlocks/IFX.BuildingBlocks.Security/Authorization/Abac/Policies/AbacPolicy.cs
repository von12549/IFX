namespace IFX.BuildingBlocks.Security.Authorization.Abac.Policies;

/// <summary>
/// A set of conditions that must ALL pass for a given resource type and action.
/// Evaluated by the generic <c>authz/common/abac_eval</c> Rego policy.
/// </summary>
public sealed class AbacPolicy
{
    /// <summary>Resource type this policy applies to (e.g. "document", "report").</summary>
    public string ResourceType { get; init; } = string.Empty;

    /// <summary>Action being performed (e.g. "read", "edit", "delete").</summary>
    public string Action { get; init; } = string.Empty;

    /// <summary>
    /// Conditions that must all evaluate to true for the policy to allow the action.
    /// An empty list results in a deny — explicit allow requires at least one condition.
    /// </summary>
    public IReadOnlyList<AbacCondition> Conditions { get; init; } = [];
}
