namespace IFX.BuildingBlocks.EntityFrameworkCore;

public static class TenantQueryGuard
{
    public static Guid Require(Guid tenantId, string parameterName = "tenantId")
    {
        if (tenantId == Guid.Empty)
        {
            throw new ArgumentException("Tenant-scoped queries require a non-empty tenant identity.", parameterName);
        }

        return tenantId;
    }
}
