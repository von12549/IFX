using IFX.Modules.IAM.Application.Ports.Authorization;

namespace IFX.Modules.IAM.Application.Tenancy.Departments.Authorization;

public class DepartmentResourceAttributes : ResourceAttributes
{

    public DepartmentResourceAttributes(Guid departmentId, Guid? tenantId, Guid? createdBy)
    {
        Type = "department";
        Id = departmentId.ToString();
        TenantId = tenantId?.ToString() ?? string.Empty;
        OwnerId = createdBy?.ToString() ?? string.Empty;
    }
}
