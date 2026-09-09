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

    public static int RequireBoundedLimit(int maxRows, int maximumAllowed = 500)
    {
        if (maxRows < 1 || maxRows > maximumAllowed)
        {
            throw new ArgumentOutOfRangeException(
                nameof(maxRows),
                maxRows,
                $"Cross-tenant query limit must be between 1 and {maximumAllowed} rows.");
        }

        return maxRows;
    }
}
