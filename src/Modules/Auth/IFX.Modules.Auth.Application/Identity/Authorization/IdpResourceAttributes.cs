using IFX.BuildingBlocks.Security.Authorization.Models;
using System.Text.Json.Serialization;

namespace IFX.Modules.Auth.Application.Identity.Authorization;

public class IdpResourceAttributes : OpaResourceAttributesBase
{
    [JsonPropertyName("owner_id")]
    public string OwnerId { get; init; } = string.Empty;

    public IdpResourceAttributes(Guid idpId, Guid? tenantId, Guid? createdBy)
    {
        Type = "idp";
        Id = idpId.ToString();
        TenantId = tenantId?.ToString() ?? string.Empty;
        OwnerId = createdBy?.ToString() ?? string.Empty;
    }
}
