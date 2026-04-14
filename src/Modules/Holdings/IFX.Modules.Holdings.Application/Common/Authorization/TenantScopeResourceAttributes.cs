using IFX.BuildingBlocks.Security.Authorization.Models;

namespace IFX.Modules.Holdings.Application.Common.Authorization;

public class TenantScopeResourceAttributes : OpaResourceAttributesBase
{
    public TenantScopeResourceAttributes(Guid? tenantId)
    {
        Type = "scope";
        Id = tenantId?.ToString() ?? string.Empty;
        TenantId = tenantId?.ToString() ?? string.Empty;
    }
}
