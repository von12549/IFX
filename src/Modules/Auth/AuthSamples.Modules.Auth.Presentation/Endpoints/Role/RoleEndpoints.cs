using AuthSamples.Modules.Auth.Application.Commands.AddRole;
using AuthSamples.Modules.Auth.Application.Commands.UpdateRole;
using AuthSamples.Modules.Auth.Application.Queries.GetAllRoles;
using AuthSamples.Modules.Auth.Presentation.Models.Requests.Role;
using AuthSamples.Modules.Auth.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Auth.Presentation.Endpoints.Role;

public static class RoleEndpoints
{
    public static async Task<IResult> GetAllRoles(
        [FromServices] IMediator mediator,
        [FromServices] ILogger logger)
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
        [FromServices] ILogger logger)
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
        [FromServices] ILogger logger)
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
