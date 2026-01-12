using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace AuthSamples.Modules.Auth.Presentation.Endpoints.Role;

public static class RoleEndpointExtensions
{
    public static IEndpointRouteBuilder MapRoleEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/role")
            .WithTags("Role")
            .RequireAuthorization(policy => policy.RequireRole("Admin"))
            ;

        group.MapGet("/", RoleEndpoints.GetAllRoles)
            .WithName("GetAllRoles")
            .WithSummary("Get all user roles (Admin only)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status403Forbidden);

        group.MapPut("/{roleId}", RoleEndpoints.UpdateRole)
            .WithName("UpdateRole")
            .WithSummary("Update an existing role (Admin only)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status403Forbidden);

        group.MapPost("/", RoleEndpoints.AddRole)
            .WithName("AddRole")
            .WithSummary("Add a new role (Admin only)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status403Forbidden);

        return builder;
    }
}
