using IFX.Modules.IAM.Application.Ports.Authorization;

namespace IFX.Modules.IAM.Application.Access.Roles.Authorization;

public class RoleResourceAttributes : ResourceAttributes
{

    public RoleResourceAttributes(Guid roleId, Guid? tenantId, Guid? createdBy)
    {
        Type = "role";
        Id = roleId.ToString();
        TenantId = tenantId?.ToString() ?? string.Empty;
        OwnerId = createdBy?.ToString() ?? string.Empty;
    }
}
