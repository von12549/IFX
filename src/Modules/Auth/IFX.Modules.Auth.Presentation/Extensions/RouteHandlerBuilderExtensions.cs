using Microsoft.AspNetCore.Builder;

namespace IFX.Modules.Auth.Presentation.Extensions;

public static class RouteHandlerBuilderExtensions
{
    /// <summary>
    /// Requires the authenticated user to hold the specified permission claim.
    /// The permission is enforced via PermissionAuthorizationPolicyProvider and
    /// PermissionAuthorizationHandler — claims are pre-loaded by UserPermissionClaimsTransformation.
    /// </summary>
    public static RouteHandlerBuilder RequirePermission(
        this RouteHandlerBuilder builder, string permissionName)
        => builder.RequireAuthorization(permissionName);
}
