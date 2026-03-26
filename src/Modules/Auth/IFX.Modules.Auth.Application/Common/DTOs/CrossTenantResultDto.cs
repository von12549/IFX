namespace IFX.Modules.Auth.Application.Common.DTOs;

public class CrossTenantResultDto<T>
{
    public IReadOnlyList<TenantGroupDto<T>> Tenants { get; init; } = [];
}
