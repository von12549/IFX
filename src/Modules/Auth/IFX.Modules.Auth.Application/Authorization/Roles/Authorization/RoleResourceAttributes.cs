using IFX.BuildingBlocks.Security.Authorization.Models;
using System.Text.Json.Serialization;

namespace IFX.Modules.Auth.Application.Authorization.Roles.Authorization;

public class RoleResourceAttributes : OpaResourceAttributesBase
{
    [JsonPropertyName("owner_id")]
    public string OwnerId { get; init; } = string.Empty;

    public RoleResourceAttributes(Guid roleId, Guid? tenantId, Guid? createdBy)
    {
        Type = "role";
        Id = roleId.ToString();
        TenantId = tenantId?.ToString() ?? string.Empty;
        OwnerId = createdBy?.ToString() ?? string.Empty;
    }
}
