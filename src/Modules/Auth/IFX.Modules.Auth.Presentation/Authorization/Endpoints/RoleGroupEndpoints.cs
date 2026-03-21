using IFX.Modules.Auth.Application.Authorization.Commands.AssignRolesToRoleGroup;
using IFX.Modules.Auth.Application.Authorization.Commands.CreateRoleGroup;
using IFX.Modules.Auth.Application.Authorization.Commands.DeleteRoleGroup;
using IFX.Modules.Auth.Application.Authorization.Commands.RemoveRoleFromRoleGroup;
using IFX.Modules.Auth.Application.Authorization.Commands.UpdateRoleGroup;
using IFX.Modules.Auth.Application.Authorization.Queries.GetAllRoleGroups;
using IFX.Modules.Auth.Presentation.Authorization.Requests;
using IFX.Modules.Auth.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Presentation.Authorization.Endpoints;

public sealed class RoleGroupEndpointsLogCategory { }

public static class RoleGroupEndpoints
{
    public static async Task<IResult> GetAllRoleGroups(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<RoleGroupEndpointsLogCategory> logger)
    {
        logger.LogInformation("Accessing role groups list");

        var result = await mediator.Send(new GetAllRoleGroupsQuery());

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreateRoleGroup(
        [FromBody] CreateRoleGroupRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<RoleGroupEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin creating role group: {Name}", request.Name);

        var result = await mediator.Send(new CreateRoleGroupCommand(request.Name, request.Description));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UpdateRoleGroup(
        Guid roleGroupId,
        [FromBody] UpdateRoleGroupRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<RoleGroupEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin updating role group: {RoleGroupId}", roleGroupId);

        var result = await mediator.Send(new UpdateRoleGroupCommand(roleGroupId, request.Name, request.Description));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> DeleteRoleGroup(
        Guid roleGroupId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<RoleGroupEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin deleting role group: {RoleGroupId}", roleGroupId);

        var result = await mediator.Send(new DeleteRoleGroupCommand(roleGroupId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> AssignRolesToRoleGroup(
        Guid roleGroupId,
        [FromBody] AssignRolesToRoleGroupRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<RoleGroupEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin assigning roles to role group: {RoleGroupId}", roleGroupId);

        var result = await mediator.Send(new AssignRolesToRoleGroupCommand(roleGroupId, request.RoleIds));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> RemoveRoleFromRoleGroup(
        Guid roleGroupId,
        Guid roleId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<RoleGroupEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin removing role {RoleId} from role group {RoleGroupId}", roleId, roleGroupId);

        var result = await mediator.Send(new RemoveRoleFromRoleGroupCommand(roleGroupId, roleId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
