namespace IFX.Modules.IAM.Application.Access.Permissions.DTOs;

public class PermissionDto
{
    public Guid Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
    public string Scope { get; init; } = string.Empty;
}
