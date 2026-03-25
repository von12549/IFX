namespace IFX.Modules.Auth.Application.Authorization.Permissions.DTOs;

public class PermissionDto
{
    public Guid Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
}
