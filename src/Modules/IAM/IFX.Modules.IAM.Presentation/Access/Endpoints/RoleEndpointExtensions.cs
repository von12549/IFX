using IFX.Modules.IAM.Presentation.Extensions;
using IFX.BuildingBlocks.Application.Context;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace IFX.Modules.IAM.Presentation.Access.Endpoints;

public static class RoleEndpointExtensions
{
    public static IEndpointRouteBuilder MapRoleEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/role")
            .WithTags("Role")
            .WithMetadata(ExecutionScopeRequirement.Tenant)
            .RequireAuthorization();

        group.MapGet("/{roleId}", RoleEndpoints.GetRoleById)
            .WithName("GetRoleById")
            .RequirePermission("Role:read")
            .WithSummary("Get a role with its permissions")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapGet("/", RoleEndpoints.GetAllRoles)
            .WithName("GetAllRoles")
            .RequirePermission("Role:list")
            .WithSummary("Get all roles")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/", RoleEndpoints.CreateRole)
            .WithName("CreateRole")
            .RequirePermission("Role:create")
            .WithSummary("Create a new role")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{roleId}", RoleEndpoints.UpdateRole)
            .WithName("UpdateRole")
            .RequirePermission("Role:update")
            .WithSummary("Update an existing role")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{roleId}", RoleEndpoints.DeleteRole)
            .WithName("DeleteRole")
            .RequirePermission("Role:delete")
            .WithSummary("Delete a role")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/{roleId}/permissions", RoleEndpoints.AssignPermissionsToRole)
            .WithName("AssignPermissionsToRole")
            .RequirePermission("Role:update")
            .WithSummary("Assign permissions to a role")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{roleId}/permissions/{permissionId}", RoleEndpoints.RemovePermissionFromRole)
            .WithName("RemovePermissionFromRole")
            .RequirePermission("Role:update")
            .WithSummary("Remove a permission from a role")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }
}
