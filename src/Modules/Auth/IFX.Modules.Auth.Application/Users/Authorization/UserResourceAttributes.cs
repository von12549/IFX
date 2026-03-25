using IFX.BuildingBlocks.Security.Authorization.Models;
using System.Text.Json.Serialization;

namespace IFX.Modules.Auth.Application.Users.Authorization;

public class UserResourceAttributes : OpaResourceAttributesBase
{
    [JsonPropertyName("owner_id")]
    public string OwnerId { get; init; } = string.Empty;

    public UserResourceAttributes(Guid userId, Guid? tenantId)
    {
        Type = "user";
        Id = userId.ToString();
        OwnerId = userId.ToString();
        TenantId = tenantId?.ToString() ?? string.Empty;
    }
}
