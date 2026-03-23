using System.Text.Json.Serialization;

namespace IFX.BuildingBlocks.Security.Authorization.Models;

public class OpaAuthorizationEnvelope<TResource> where TResource : OpaResourceAttributesBase
{
    [JsonPropertyName("subject")]
    public OpaSubjectAttributes Subject { get; init; } = null!;

    [JsonPropertyName("resource")]
    public TResource Resource { get; init; } = null!;

    [JsonPropertyName("action")]
    public string Action { get; init; } = string.Empty;

    [JsonPropertyName("environment")]
    public OpaEnvironmentAttributes Environment { get; init; } = null!;
}
