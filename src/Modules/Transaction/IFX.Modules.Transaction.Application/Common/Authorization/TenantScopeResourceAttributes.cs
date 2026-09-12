using IFX.Modules.Transaction.Application.Ports.Authorization;


namespace IFX.Modules.Transaction.Application.Common.Authorization;

public class TenantScopeResourceAttributes : ResourceAttributes
{
    public TenantScopeResourceAttributes(Guid? tenantId)
    {
        Type = "scope";
        Id = tenantId?.ToString() ?? string.Empty;
        TenantId = tenantId?.ToString() ?? string.Empty;
    }
}
