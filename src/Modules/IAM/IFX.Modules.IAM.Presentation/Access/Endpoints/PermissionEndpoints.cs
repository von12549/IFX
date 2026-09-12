using IFX.Modules.IAM.Application.Access.Permissions.Commands.CreatePermission;
using IFX.Modules.IAM.Application.Access.Permissions.Commands.DeletePermission;
using IFX.Modules.IAM.Application.Access.Permissions.Commands.UpdatePermission;
using IFX.Modules.IAM.Application.Access.Permissions.Queries.GetAllPermissions;
using IFX.Modules.IAM.Presentation.Access.Requests;
using IFX.Modules.IAM.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Presentation.Access.Endpoints;

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
