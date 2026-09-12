using IFX.Modules.Holdings.Application.Ports.Authorization;


namespace IFX.Modules.Holdings.Application.Common.Authorization;

public class TenantScopeResourceAttributes : ResourceAttributes
{
    public TenantScopeResourceAttributes(Guid? tenantId)
    {
        Type = "scope";
        Id = tenantId?.ToString() ?? string.Empty;
        TenantId = tenantId?.ToString() ?? string.Empty;
    }
}
