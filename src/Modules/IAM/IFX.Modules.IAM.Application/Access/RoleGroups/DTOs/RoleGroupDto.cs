using IFX.Modules.IAM.Application.Access.Roles.DTOs;

namespace IFX.Modules.IAM.Application.Access.RoleGroups.DTOs;

public class RoleGroupDto
{
    public Guid Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public string TenantName { get; init; } = string.Empty;
    public List<RoleDto> Roles { get; init; } = [];
}
