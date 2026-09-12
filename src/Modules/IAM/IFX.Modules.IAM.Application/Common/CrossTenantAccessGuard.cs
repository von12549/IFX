using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;

namespace IFX.Modules.IAM.Application.Common;

public static class CrossTenantAccessGuard
{
    public const int MaximumRows = 500;
    public const string RequiredPermission = "Platform.GlobalRole:manage";

    private static readonly HashSet<string> AllowedGlobalRoles = new(StringComparer.OrdinalIgnoreCase)
    {
        GlobalRoleNames.PlatformAdmin,
        GlobalRoleNames.PlatformSupport,
        GlobalRoleNames.PlatformAuditor
    };

    public static async Task RequireAsync(ICurrentUser currentUser, IPermissionChecker permission, CancellationToken ct = default)
    {
        var hasAllowedRole = currentUser.GlobalRoles.Any(AllowedGlobalRoles.Contains);
        var hasPermission = currentUser.TenantId is null && await permission.HasPermissionAsync(RequiredPermission, ct);

        if (!currentUser.IsAuthenticated || currentUser.UserId == Guid.Empty || !hasAllowedRole || !hasPermission)
        {
            throw new ForbiddenException("Platform global role and cross-tenant permission are required.");
        }
    }
}

public static class TenantAccessGuard
{
    public static Guid RequireTenant(ICurrentUser currentUser)
    {
        if (!currentUser.IsAuthenticated || currentUser.TenantId is not { } tenantId || tenantId == Guid.Empty)
        {
            throw new ForbiddenException("A trusted tenant execution scope is required.");
        }

        return tenantId;
    }
}
