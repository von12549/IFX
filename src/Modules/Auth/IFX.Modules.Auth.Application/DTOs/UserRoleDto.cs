namespace IFX.Modules.Auth.Application.DTOs;

public class UserRoleDto
{
    public Guid Id { get; init; }
    public string RoleName { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
}
