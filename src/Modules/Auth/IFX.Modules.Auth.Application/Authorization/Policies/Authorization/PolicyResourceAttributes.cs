using IFX.BuildingBlocks.Security.Authorization.Models;
using System.Text.Json.Serialization;

namespace IFX.Modules.Auth.Application.Authorization.Policies.Authorization;

public class PolicyResourceAttributes : OpaResourceAttributesBase
{
    [JsonPropertyName("owner_id")]
    public string OwnerId { get; init; } = string.Empty;

    public PolicyResourceAttributes(Guid policyId, Guid? tenantId, Guid? createdById)
    {
        Type = "policy";
        Id = policyId.ToString();
        TenantId = tenantId?.ToString() ?? string.Empty;
        OwnerId = createdById?.ToString() ?? string.Empty;
    }
}
