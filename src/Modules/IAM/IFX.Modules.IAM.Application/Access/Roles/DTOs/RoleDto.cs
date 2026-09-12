namespace IFX.Modules.IAM.Application.Access.Roles.DTOs;

public class RoleDto
{
    public Guid Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public string TenantName { get; init; } = string.Empty;
}
