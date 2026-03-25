using IFX.Modules.Auth.Presentation.Extensions;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace IFX.Modules.Auth.Presentation.Authorization.Endpoints;

public static class GlobalRoleEndpointExtensions
{
    public static IEndpointRouteBuilder MapGlobalRoleEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/platform")
            .WithTags("Platform GlobalRoles")
            .RequireAuthorization();

        group.MapGet("/globalroles", GlobalRoleEndpoints.ListGlobalRoles)
            .WithName("ListGlobalRoles")
            .RequirePermission("Platform.GlobalRole:manage")
            .WithSummary("List all global roles")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/users/{userId}/globalroles", GlobalRoleEndpoints.GetUserGlobalRoles)
            .WithName("GetUserGlobalRoles")
            .RequirePermission("Platform.GlobalRole:manage")
            .WithSummary("Get global roles assigned to a user")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/users/{userId}/globalroles", GlobalRoleEndpoints.AssignGlobalRole)
            .WithName("AssignGlobalRole")
            .RequirePermission("Platform.GlobalRole:manage")
            .WithSummary("Assign a global role to a user")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/users/{userId}/globalroles/{roleId}", GlobalRoleEndpoints.RemoveGlobalRole)
            .WithName("RemoveGlobalRole")
            .RequirePermission("Platform.GlobalRole:manage")
            .WithSummary("Remove a global role from a user")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }
}
