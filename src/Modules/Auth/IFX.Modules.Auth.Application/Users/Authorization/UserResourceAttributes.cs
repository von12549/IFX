using IFX.BuildingBlocks.Security.Authorization.Models;

namespace IFX.Modules.Auth.Application.Users.Authorization;

public class UserResourceAttributes : OpaResourceAttributesBase
{
    public UserResourceAttributes(Guid userId, Guid? tenantId)
    {
        Type = "user";
        Id = userId.ToString();
        TenantId = tenantId?.ToString() ?? string.Empty;
    }
}
