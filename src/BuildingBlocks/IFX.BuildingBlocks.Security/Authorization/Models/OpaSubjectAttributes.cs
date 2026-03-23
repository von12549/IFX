using System.Text.Json.Serialization;

namespace IFX.BuildingBlocks.Security.Authorization.Models;

public class OpaSubjectAttributes
{
    [JsonPropertyName("id")]
    public string Id { get; init; } = string.Empty;

    [JsonPropertyName("tenant_id")]
    public string? TenantId { get; init; }

    [JsonPropertyName("departments")]
    public IReadOnlyCollection<string> Departments { get; init; } = [];

    [JsonPropertyName("roles")]
    public IReadOnlyCollection<string> Roles { get; init; } = [];

    [JsonPropertyName("permissions")]
    public IReadOnlyCollection<string> Permissions { get; init; } = [];

    [JsonPropertyName("mfa")]
    public bool Mfa { get; init; }
}
