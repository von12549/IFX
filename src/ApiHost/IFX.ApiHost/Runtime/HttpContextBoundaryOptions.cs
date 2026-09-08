namespace IFX.ApiHost.Runtime;

public sealed class HttpContextBoundaryOptions
{
    public const string SectionName = "HttpContextBoundary";

    public bool AllowTrustedGatewayCorrelationPropagation { get; init; }

    public string[] TrustedGatewayAddresses { get; init; } = [];
}
