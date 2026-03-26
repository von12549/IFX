namespace IFX.Modules.Auth.Application.Common.DTOs;

public class TenantGroupDto<T>
{
    public Guid TenantId { get; init; }
    public string TenantName { get; init; } = string.Empty;
    public IReadOnlyList<T> Items { get; init; } = [];
}
