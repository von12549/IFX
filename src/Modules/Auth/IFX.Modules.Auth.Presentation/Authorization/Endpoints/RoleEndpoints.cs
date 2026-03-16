using IFX.Modules.Auth.Application.Authorization.Commands.AddRole;
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

        var query = new GetAllRolesQuery();
        var result = await mediator.Send(query);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UpdateRole(
        Guid roleId,
        [FromBody] UpdateRoleRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<RoleEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin updating role: {RoleId}", roleId);

        var command = new UpdateRoleCommand(roleId, request.RoleName, request.Description);
        var result = await mediator.Send(command);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> AddRole(
        [FromBody] AddRoleRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<RoleEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin adding new role: {RoleName}", request.RoleName);

        var command = new AddRoleCommand(request.RoleName, request.Description);
        var result = await mediator.Send(command);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
