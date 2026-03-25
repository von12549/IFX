using System.Text.Json.Serialization;
using IFX.BuildingBlocks.Security.Authorization.Abac.Policies;

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

    /// <summary>
    /// Resolved ABAC conditions produced by <see cref="Engine.IAbacPolicyEngine"/>.
    /// Null when using resource-specific Rego policy paths — the field is omitted from JSON
    /// so existing policies are unaffected.
    /// </summary>
    [JsonPropertyName("conditions")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public IReadOnlyList<ResolvedCondition>? Conditions { get; init; }
}
