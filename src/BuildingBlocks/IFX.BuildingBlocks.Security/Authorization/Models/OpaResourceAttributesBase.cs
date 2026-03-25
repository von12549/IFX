using System.Text.Json.Serialization;

namespace IFX.BuildingBlocks.Security.Authorization.Models;

public abstract class OpaResourceAttributesBase
{
    [JsonPropertyName("type")]
    public string Type { get; init; } = string.Empty;

    [JsonPropertyName("id")]
    public string Id { get; init; } = string.Empty;

    [JsonPropertyName("tenant_id")]
    public string TenantId { get; init; } = string.Empty;

    [JsonPropertyName("is_active")]
    public string IsActive { get; init; } = string.Empty;
}
