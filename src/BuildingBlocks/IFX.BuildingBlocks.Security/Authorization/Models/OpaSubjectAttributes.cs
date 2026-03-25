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

    [JsonPropertyName("global_roles")]
    public IReadOnlyList<string> GlobalRoles { get; init; } = [];

    /// <summary>
    /// Serialized as "true"/"false" string for consistent Rego equality checks
    /// (same pattern as resource.is_active).
    /// </summary>
    [JsonPropertyName("is_global_admin")]
    public string IsGlobalAdmin { get; init; } = "false";
}
