using Microsoft.AspNetCore.Builder;

namespace IFX.Modules.Holdings.Presentation.Extensions;

public static class RouteHandlerBuilderExtensions
{
    /// <summary>
    /// Requires the authenticated user to hold the specified permission claim.
    /// </summary>
    public static RouteHandlerBuilder RequirePermission(
        this RouteHandlerBuilder builder, string permissionName)
        => builder.RequireAuthorization(permissionName);
}
