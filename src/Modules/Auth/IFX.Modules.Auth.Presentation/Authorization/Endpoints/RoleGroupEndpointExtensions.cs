using IFX.Modules.Auth.Presentation.Extensions;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace IFX.Modules.Auth.Presentation.Authorization.Endpoints;

public static class RoleGroupEndpointExtensions
{
    public static IEndpointRouteBuilder MapRoleGroupEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/rolegroup")
            .WithTags("RoleGroup")
            .RequireAuthorization();

        group.MapGet("/", RoleGroupEndpoints.GetAllRoleGroups)
            .WithName("GetAllRoleGroups")
            .RequirePermission("RoleGroup.Read")
            .WithSummary("Get all role groups")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/", RoleGroupEndpoints.CreateRoleGroup)
            .WithName("CreateRoleGroup")
            .RequirePermission("RoleGroup.Write")
            .WithSummary("Create a new role group")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{roleGroupId}", RoleGroupEndpoints.UpdateRoleGroup)
            .WithName("UpdateRoleGroup")
            .RequirePermission("RoleGroup.Write")
            .WithSummary("Update an existing role group")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{roleGroupId}", RoleGroupEndpoints.DeleteRoleGroup)
            .WithName("DeleteRoleGroup")
            .RequirePermission("RoleGroup.Write")
            .WithSummary("Delete a role group")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/{roleGroupId}/roles", RoleGroupEndpoints.AssignRolesToRoleGroup)
            .WithName("AssignRolesToRoleGroup")
            .RequirePermission("RoleGroup.Write")
            .WithSummary("Assign roles to a role group")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{roleGroupId}/roles/{roleId}", RoleGroupEndpoints.RemoveRoleFromRoleGroup)
            .WithName("RemoveRoleFromRoleGroup")
            .RequirePermission("RoleGroup.Write")
            .WithSummary("Remove a role from a role group")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }
}
