using IFX.BuildingBlocks.Security.Authorization.Models;
using System.Text.Json.Serialization;

namespace IFX.Modules.IAM.Application.Tenancy.Departments.Authorization;

public class DepartmentResourceAttributes : OpaResourceAttributesBase
{
    [JsonPropertyName("owner_id")]
    public string OwnerId { get; init; } = string.Empty;

    public DepartmentResourceAttributes(Guid departmentId, Guid? tenantId, Guid? createdBy)
    {
        Type = "department";
        Id = departmentId.ToString();
        TenantId = tenantId?.ToString() ?? string.Empty;
        OwnerId = createdBy?.ToString() ?? string.Empty;
    }
}
