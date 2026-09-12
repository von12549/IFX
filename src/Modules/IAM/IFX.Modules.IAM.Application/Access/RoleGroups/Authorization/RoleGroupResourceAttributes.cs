using IFX.Modules.IAM.Application.Ports.Authorization;

namespace IFX.Modules.IAM.Application.Access.RoleGroups.Authorization;

public class RoleGroupResourceAttributes : ResourceAttributes
{

    public RoleGroupResourceAttributes(Guid groupId, Guid? tenantId, Guid? createdBy)
    {
        Type = "rolegroup";
        Id = groupId.ToString();
        TenantId = tenantId?.ToString() ?? string.Empty;
        OwnerId = createdBy?.ToString() ?? string.Empty;
    }
}
