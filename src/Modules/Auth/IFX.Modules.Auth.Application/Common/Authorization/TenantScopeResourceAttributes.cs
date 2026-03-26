using IFX.BuildingBlocks.Security.Authorization.Models;

namespace IFX.Modules.Auth.Application.Common.Authorization;

/// <summary>
/// Generic resource attributes for list/create gates where no specific resource row exists yet.
/// The SameTenant condition evaluates subject.tenant_id == resource.tenant_id — i.e., "does the
/// user belong to the tenant they're querying?" — which is the correct coarse-grained gate.
/// </summary>
public class TenantScopeResourceAttributes : OpaResourceAttributesBase
{
    public TenantScopeResourceAttributes(Guid? tenantId)
    {
        Type = "scope";
        Id = tenantId?.ToString() ?? string.Empty;
        TenantId = tenantId?.ToString() ?? string.Empty;
    }
}
