namespace IFX.Modules.Auth.Application.Authorization.Tenants.DTOs;

public class TenantDto
{
    public Guid Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
}
