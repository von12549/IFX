using IFX.Modules.Auth.Application.Authorization.Commands.AssignPermissionsToRole;
using IFX.Modules.Auth.Application.Authorization.Commands.CreateRole;
using IFX.Modules.Auth.Application.Authorization.Commands.DeleteRole;
using IFX.Modules.Auth.Application.Authorization.Commands.RemovePermissionFromRole;
using IFX.Modules.Auth.Application.Authorization.Commands.UpdateRole;
using IFX.Modules.Auth.Application.Authorization.Queries.GetAllRoles;
using IFX.Modules.Auth.Presentation.Authorization.Requests;
using IFX.Modules.Auth.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Presentation.Authorization.Endpoints;

public sealed class RoleEndpointsLogCategory { }

public static class RoleEndpoints
{
    public static async Task<IResult> GetAllRoles(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<RoleEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin accessing roles list");

        var result = await mediator.Send(new GetAllRolesQuery());

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreateRole(
        [FromBody] CreateRoleRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<RoleEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin creating role: {Name}", request.Name);

        var result = await mediator.Send(new CreateRoleCommand(request.Name, request.Description));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UpdateRole(
        Guid roleId,
        [FromBody] UpdateRoleRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<RoleEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin updating role: {RoleId}", roleId);

        var result = await mediator.Send(new UpdateRoleCommand(roleId, request.Name, request.Description));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> DeleteRole(
        Guid roleId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<RoleEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin deleting role: {RoleId}", roleId);

        var result = await mediator.Send(new DeleteRoleCommand(roleId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> AssignPermissionsToRole(
        Guid roleId,
        [FromBody] AssignPermissionsToRoleRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<RoleEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin assigning permissions to role: {RoleId}", roleId);

        var result = await mediator.Send(new AssignPermissionsToRoleCommand(roleId, request.PermissionIds));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> RemovePermissionFromRole(
        Guid roleId,
        Guid permissionId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<RoleEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin removing permission {PermissionId} from role {RoleId}", permissionId, roleId);

        var result = await mediator.Send(new RemovePermissionFromRoleCommand(roleId, permissionId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
