namespace IFX.BuildingBlocks.Security.Authorization.Models;

public class OpaDecisionResult
{
    public bool Allow { get; private init; }
    public string? DenyReason { get; private init; }

    public static OpaDecisionResult Allowed() => new() { Allow = true };

    public static OpaDecisionResult Denied(string? reason = null) =>
        new() { Allow = false, DenyReason = reason };
}
