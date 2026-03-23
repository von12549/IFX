using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Models;
using Microsoft.Extensions.Logging;

namespace IFX.BuildingBlocks.Security.Authorization.Opa;

/// <summary>
/// No-op OPA client for local development when OPA is not running (Opa:Enabled = false).
/// Always returns allow.
/// </summary>
public class NullOpaPolicyClient : IOpaPolicyClient
{
    private readonly ILogger<NullOpaPolicyClient> _logger;

    public NullOpaPolicyClient(ILogger<NullOpaPolicyClient> logger)
    {
        _logger = logger;
    }

    public Task<OpaDecisionResult> EvaluateAsync(string decisionPath, object input, CancellationToken ct = default)
    {
        _logger.LogDebug("NullOpaPolicyClient: OPA disabled — allowing {Path}", decisionPath);
        return Task.FromResult(OpaDecisionResult.Allowed());
    }
}
