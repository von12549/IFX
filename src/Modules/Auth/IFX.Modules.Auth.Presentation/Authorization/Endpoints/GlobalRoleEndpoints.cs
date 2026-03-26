using IFX.Modules.Auth.Application.Authorization.Departments.Queries.GetAllDepartmentsAcrossTenants;
using IFX.Modules.Auth.Application.Authorization.GlobalRoles.Commands.AssignGlobalRole;
using IFX.Modules.Auth.Application.Authorization.GlobalRoles.Commands.RemoveGlobalRole;
using IFX.Modules.Auth.Application.Authorization.GlobalRoles.Queries.GetUserGlobalRoles;
using IFX.Modules.Auth.Application.Authorization.GlobalRoles.Queries.ListGlobalRoles;
using IFX.Modules.Auth.Application.Authorization.RoleGroups.Queries.GetAllRoleGroupsAcrossTenants;
using IFX.Modules.Auth.Application.Authorization.Roles.Queries.GetAllRolesAcrossTenants;
using IFX.Modules.Auth.Application.Identity.Queries.GetAllIdpsAcrossTenants;
using IFX.Modules.Auth.Application.Users.Queries.GetAllUsersAcrossTenants;
using IFX.Modules.Auth.Presentation.Authorization.Requests;
using IFX.Modules.Auth.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Presentation.Authorization.Endpoints;

public sealed class GlobalRoleEndpointsLogCategory { }

public static class GlobalRoleEndpoints
{
    public static async Task<IResult> ListGlobalRoles(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<GlobalRoleEndpointsLogCategory> logger)
    {
        logger.LogInformation("Listing all global roles");
        var result = await mediator.Send(new ListGlobalRolesQuery());

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetUserGlobalRoles(
        Guid userId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<GlobalRoleEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting global roles for user {UserId}", userId);
        var result = await mediator.Send(new GetUserGlobalRolesQuery(userId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> AssignGlobalRole(
        Guid userId,
        [FromBody] AssignGlobalRoleRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<GlobalRoleEndpointsLogCategory> logger)
    {
        logger.LogInformation("Assigning global role {GlobalRoleId} to user {UserId}", request.GlobalRoleId, userId);
        var result = await mediator.Send(new AssignGlobalRoleCommand(userId, request.GlobalRoleId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> RemoveGlobalRole(
        Guid userId,
        Guid roleId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<GlobalRoleEndpointsLogCategory> logger)
    {
        logger.LogInformation("Removing global role {RoleId} from user {UserId}", roleId, userId);
        var result = await mediator.Send(new RemoveGlobalRoleCommand(userId, roleId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetAllUsersAcrossTenants(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<GlobalRoleEndpointsLogCategory> logger)
    {
        logger.LogInformation("Listing users across all tenants");
        var result = await mediator.Send(new GetAllUsersAcrossTenantsQuery());
        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetAllRolesAcrossTenants(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<GlobalRoleEndpointsLogCategory> logger)
    {
        logger.LogInformation("Listing roles across all tenants");
        var result = await mediator.Send(new GetAllRolesAcrossTenantsQuery());
        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetAllRoleGroupsAcrossTenants(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<GlobalRoleEndpointsLogCategory> logger)
    {
        logger.LogInformation("Listing role groups across all tenants");
        var result = await mediator.Send(new GetAllRoleGroupsAcrossTenantsQuery());
        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetAllDepartmentsAcrossTenants(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<GlobalRoleEndpointsLogCategory> logger)
    {
        logger.LogInformation("Listing departments across all tenants");
        var result = await mediator.Send(new GetAllDepartmentsAcrossTenantsQuery());
        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetAllIdpsAcrossTenants(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<GlobalRoleEndpointsLogCategory> logger)
    {
        logger.LogInformation("Listing IdPs across all tenants");
        var result = await mediator.Send(new GetAllIdpsAcrossTenantsQuery());
        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
