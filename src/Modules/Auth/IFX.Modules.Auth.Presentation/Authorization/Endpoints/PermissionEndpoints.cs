using IFX.Modules.Auth.Application.Authorization.Permissions.Commands.CreatePermission;
using IFX.Modules.Auth.Application.Authorization.Permissions.Commands.DeletePermission;
using IFX.Modules.Auth.Application.Authorization.Permissions.Commands.UpdatePermission;
using IFX.Modules.Auth.Application.Authorization.Permissions.Queries.GetAllPermissions;
using IFX.Modules.Auth.Presentation.Authorization.Requests;
using IFX.Modules.Auth.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Presentation.Authorization.Endpoints;

public sealed class PermissionEndpointsLogCategory { }

public static class PermissionEndpoints
{
    public static async Task<IResult> GetAllPermissions(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PermissionEndpointsLogCategory> logger)
    {
        logger.LogInformation("Accessing permissions list");

        var result = await mediator.Send(new GetAllPermissionsQuery());

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreatePermission(
        [FromBody] CreatePermissionRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PermissionEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin creating permission: {Name}", request.Name);

        var result = await mediator.Send(new CreatePermissionCommand(request.Name, request.Description));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UpdatePermission(
        Guid permissionId,
        [FromBody] UpdatePermissionRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PermissionEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin updating permission: {PermissionId}", permissionId);

        var result = await mediator.Send(new UpdatePermissionCommand(permissionId, request.Name, request.Description));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> DeletePermission(
        Guid permissionId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PermissionEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin deleting permission: {PermissionId}", permissionId);

        var result = await mediator.Send(new DeletePermissionCommand(permissionId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
