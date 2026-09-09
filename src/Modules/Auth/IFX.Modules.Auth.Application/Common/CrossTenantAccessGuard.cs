using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.Auth.Domain.Authorization;

namespace IFX.Modules.Auth.Application.Common;

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

    public static void Require(ICurrentUser currentUser)
    {
        var hasAllowedRole = currentUser.GlobalRoles.Any(AllowedGlobalRoles.Contains);
        var hasPermission = currentUser.Permissions.Contains(RequiredPermission, StringComparer.OrdinalIgnoreCase);

        if (!currentUser.IsAuthenticated || currentUser.UserId == Guid.Empty || !hasAllowedRole || !hasPermission)
        {
            throw new ForbiddenException("Platform global role and cross-tenant permission are required.");
        }
    }
}
