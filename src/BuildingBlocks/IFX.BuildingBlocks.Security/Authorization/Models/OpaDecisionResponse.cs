using System.Text.Json.Serialization;

namespace IFX.BuildingBlocks.Security.Authorization.Models;

/// <summary>
/// Raw JSON response from OPA: { "result": { "allow": true } }
/// </summary>
public class OpaDecisionResponse
{
    [JsonPropertyName("result")]
    public OpaResultBody? Result { get; init; }
}

public class OpaResultBody
{
    [JsonPropertyName("allow")]
    public bool Allow { get; init; }
}
