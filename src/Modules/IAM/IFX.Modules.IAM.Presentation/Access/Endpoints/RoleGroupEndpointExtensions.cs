using IFX.Modules.IAM.Presentation.Extensions;
using IFX.BuildingBlocks.Application.Context;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace IFX.Modules.IAM.Presentation.Access.Endpoints;

public static class RoleGroupEndpointExtensions
{
    public static IEndpointRouteBuilder MapRoleGroupEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/rolegroup")
            .WithTags("RoleGroup")
            .WithMetadata(ExecutionScopeRequirement.Tenant)
            .RequireAuthorization();

        group.MapGet("/", RoleGroupEndpoints.GetAllRoleGroups)
            .WithName("GetAllRoleGroups")
            .RequirePermission("RoleGroup:list")
            .WithSummary("Get all role groups")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/", RoleGroupEndpoints.CreateRoleGroup)
            .WithName("CreateRoleGroup")
            .RequirePermission("RoleGroup:create")
            .WithSummary("Create a new role group")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{roleGroupId}", RoleGroupEndpoints.UpdateRoleGroup)
            .WithName("UpdateRoleGroup")
            .RequirePermission("RoleGroup:update")
            .WithSummary("Update an existing role group")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{roleGroupId}", RoleGroupEndpoints.DeleteRoleGroup)
            .WithName("DeleteRoleGroup")
            .RequirePermission("RoleGroup:delete")
            .WithSummary("Delete a role group")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/{roleGroupId}/roles", RoleGroupEndpoints.AssignRolesToRoleGroup)
            .WithName("AssignRolesToRoleGroup")
            .RequirePermission("RoleGroup:update")
            .WithSummary("Assign roles to a role group")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{roleGroupId}/roles/{roleId}", RoleGroupEndpoints.RemoveRoleFromRoleGroup)
            .WithName("RemoveRoleFromRoleGroup")
            .RequirePermission("RoleGroup:update")
            .WithSummary("Remove a role from a role group")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }
}
