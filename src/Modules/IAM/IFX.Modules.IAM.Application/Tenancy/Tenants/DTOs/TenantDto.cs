namespace IFX.Modules.IAM.Application.Tenancy.Tenants.DTOs;

public class TenantDto
{
    public bool IsActive { get; init; } = true;
    public Guid Id { get; init; }
    public string Name { get; init; } = string.Empty;
    public string Description { get; init; } = string.Empty;
}
