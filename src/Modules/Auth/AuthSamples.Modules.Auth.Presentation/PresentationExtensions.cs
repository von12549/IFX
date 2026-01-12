using AuthSamples.Modules.Auth.Presentation.Endpoints.Auth;
using AuthSamples.Modules.Auth.Presentation.Endpoints.Idp;
using AuthSamples.Modules.Auth.Presentation.Endpoints.Role;
using AuthSamples.Modules.Auth.Presentation.Endpoints.User;
using AuthSamples.Modules.Auth.Presentation.Endpoints.UserManagement;
using Microsoft.AspNetCore.Routing;

namespace AuthSamples.Modules.Auth.Presentation;

/// <summary>
/// Extension methods for registering all Auth module endpoints
/// </summary>
public static class PresentationExtensions
{
    /// <summary>
    /// Maps all Auth module endpoints (19 total: 6 Auth, 5 User, 2 UserManagement, 3 Role, 3 Idp)
    /// </summary>
    /// <param name="builder">The endpoint route builder</param>
    /// <returns>The endpoint route builder for chaining</returns>
    public static IEndpointRouteBuilder AddAuthModuleEndpoints(this IEndpointRouteBuilder builder)
    {
        builder.MapAuthEndpoints();          // 6 endpoints: register, confirm, login, refresh, revoke, logout
        return builder;
    }

    public static IEndpointRouteBuilder AddUserModuleEndpoints(this IEndpointRouteBuilder builder)
    {
        builder.MapUserEndpoints();          // 5 endpoints: profile (GET/PUT), login-history, activity-log, sync
        return builder;
    }

    public static IEndpointRouteBuilder AddUserManagementModuleEndpoints(this IEndpointRouteBuilder builder)
    {
        builder.MapUserManagementEndpoints(); // 2 endpoints: users (GET/PUT) - Admin only
        return builder;
    }

    public static IEndpointRouteBuilder AddRoleModuleEndpoints(this IEndpointRouteBuilder builder)
    {
        builder.MapRoleEndpoints();          // 3 endpoints: roles (GET/POST/PUT) - Admin only
        return builder;
    }

    public static IEndpointRouteBuilder AddIdpModuleEndpoints(this IEndpointRouteBuilder builder)
    {
        builder.MapIdpEndpoints();           // 3 endpoints: idps (GET/POST/PUT) - Admin only
        return builder;
    }
}
