namespace IFX.Modules.Auth.Application.Authorization.DTOs;

public class PermissionDto
{
    public Guid Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
}
