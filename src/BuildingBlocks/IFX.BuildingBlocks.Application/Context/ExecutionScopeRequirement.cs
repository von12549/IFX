namespace IFX.BuildingBlocks.Application.Context;

public enum ExecutionScopeRequirementKind
{
    Tenant = 1,
    Platform = 2
}

public sealed class ExecutionScopeRequirement
{
    private ExecutionScopeRequirement(
        ExecutionScopeRequirementKind kind,
        bool allowAnonymous,
        bool allowPrimaryTenantFallback)
    {
        Kind = kind;
        AllowAnonymous = allowAnonymous;
        AllowPrimaryTenantFallback = allowPrimaryTenantFallback;
    }

    public ExecutionScopeRequirementKind Kind { get; }

    public bool AllowAnonymous { get; }

    public bool AllowPrimaryTenantFallback { get; }

    public static ExecutionScopeRequirement Tenant { get; } = new(
        ExecutionScopeRequirementKind.Tenant,
        allowAnonymous: false,
        allowPrimaryTenantFallback: true);

    public static ExecutionScopeRequirement Platform { get; } = new(
        ExecutionScopeRequirementKind.Platform,
        allowAnonymous: false,
        allowPrimaryTenantFallback: false);

    public static ExecutionScopeRequirement Public { get; } = new(
        ExecutionScopeRequirementKind.Platform,
        allowAnonymous: true,
        allowPrimaryTenantFallback: false);
}
