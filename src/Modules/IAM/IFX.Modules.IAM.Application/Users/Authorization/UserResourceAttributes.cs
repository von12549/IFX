using IFX.Modules.IAM.Application.Ports.Authorization;

namespace IFX.Modules.IAM.Application.Users.Authorization;

public class UserResourceAttributes : ResourceAttributes
{

    public UserResourceAttributes(Guid userId, Guid? tenantId)
    {
        Type = "user";
        Id = userId.ToString();
        OwnerId = userId.ToString();
        TenantId = tenantId?.ToString() ?? string.Empty;
    }
}
