using IFX.Modules.IAM.Presentation.Extensions;
using IFX.BuildingBlocks.Application.Context;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace IFX.Modules.IAM.Presentation.Access.Endpoints;

public static class PermissionEndpointExtensions
{
    public static IEndpointRouteBuilder MapPermissionEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/permission")
            .WithTags("Permission")
            .WithMetadata(ExecutionScopeRequirement.Tenant)
            .RequireAuthorization();

        group.MapGet("/", PermissionEndpoints.GetAllPermissions)
            .WithName("GetAllPermissions")
            .RequirePermission("Permission:list")
            .WithSummary("Get all permissions")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/", PermissionEndpoints.CreatePermission)
            .WithName("CreatePermission")
            .RequirePermission("Permission:create")
            .WithSummary("Create a new permission")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{permissionId}", PermissionEndpoints.UpdatePermission)
            .WithName("UpdatePermission")
            .RequirePermission("Permission:update")
            .WithSummary("Update an existing permission")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{permissionId}", PermissionEndpoints.DeletePermission)
            .WithName("DeletePermission")
            .RequirePermission("Permission:delete")
            .WithSummary("Delete a permission")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }
}
