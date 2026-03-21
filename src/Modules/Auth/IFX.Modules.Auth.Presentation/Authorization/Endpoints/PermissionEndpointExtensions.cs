using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace IFX.Modules.Auth.Presentation.Authorization.Endpoints;

public static class PermissionEndpointExtensions
{
    public static IEndpointRouteBuilder MapPermissionEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/permission")
            .WithTags("Permission")
            .RequireAuthorization();

        group.MapGet("/", PermissionEndpoints.GetAllPermissions)
            .WithName("GetAllPermissions")
            .WithSummary("Get all permissions")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/", PermissionEndpoints.CreatePermission)
            .WithName("CreatePermission")
            .WithSummary("Create a new permission")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{permissionId}", PermissionEndpoints.UpdatePermission)
            .WithName("UpdatePermission")
            .WithSummary("Update an existing permission")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{permissionId}", PermissionEndpoints.DeletePermission)
            .WithName("DeletePermission")
            .WithSummary("Delete a permission")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }
}
