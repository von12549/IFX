using IFX.BuildingBlocks.Security.Authorization.Models;

namespace IFX.BuildingBlocks.Security.Authorization.Abstractions;

public interface IOpaPolicyClient
{
    Task<OpaDecisionResult> EvaluateAsync(string decisionPath, object input, CancellationToken ct = default);
}
