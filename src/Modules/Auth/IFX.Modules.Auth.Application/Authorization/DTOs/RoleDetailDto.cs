namespace IFX.Modules.Auth.Application.Authorization.DTOs;

public class RoleDetailDto
{
    public Guid Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public string TenantName { get; init; } = string.Empty;
    public List<PermissionDto> Permissions { get; init; } = [];
}
