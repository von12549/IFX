using IFX.BuildingBlocks.Security.Authorization.Models;
using System.Text.Json.Serialization;

namespace IFX.Modules.Auth.Application.Authorization.Authorization;

public class RoleGroupResourceAttributes : OpaResourceAttributesBase
{
    [JsonPropertyName("owner_id")]
    public string OwnerId { get; init; } = string.Empty;

    public RoleGroupResourceAttributes(Guid groupId, Guid? tenantId, Guid? createdBy)
    {
        Type = "rolegroup";
        Id = groupId.ToString();
        TenantId = tenantId?.ToString() ?? string.Empty;
        OwnerId = createdBy?.ToString() ?? string.Empty;
    }
}
