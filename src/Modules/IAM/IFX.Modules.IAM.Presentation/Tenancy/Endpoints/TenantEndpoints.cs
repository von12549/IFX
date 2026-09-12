using IFX.Modules.IAM.Application.Tenancy.Tenants.Commands.CreateTenant;
using IFX.Modules.IAM.Application.Tenancy.Tenants.Commands.DeleteTenant;
using IFX.Modules.IAM.Application.Tenancy.Tenants.Commands.UpdateTenant;
using IFX.Modules.IAM.Application.Tenancy.Tenants.Queries.GetAllTenants;
using IFX.Modules.IAM.Application.Tenancy.Tenants.Queries.GetTenantById;
using IFX.Modules.IAM.Presentation.Access.Requests;
using IFX.Modules.IAM.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Presentation.Tenancy.Endpoints;

public sealed class TenantEndpointsLogCategory { }

public static class TenantEndpoints
{
    public static async Task<IResult> GetAllTenants(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<TenantEndpointsLogCategory> logger)
    {
        logger.LogInformation("Accessing tenants list");

        var result = await mediator.Send(new GetAllTenantsQuery());

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetTenantById(
        Guid tenantId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<TenantEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting tenant: {TenantId}", tenantId);

        var result = await mediator.Send(new GetTenantByIdQuery(tenantId));

        if (!result.IsSuccess)
            return Results.NotFound(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreateTenant(
        [FromBody] CreateTenantRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<TenantEndpointsLogCategory> logger)
    {
        logger.LogInformation("Creating tenant: {Name}", request.Name);

        var result = await mediator.Send(new CreateTenantCommand(request.Name, request.Description));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UpdateTenant(
        Guid tenantId,
        [FromBody] UpdateTenantRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<TenantEndpointsLogCategory> logger)
    {
        logger.LogInformation("Updating tenant: {TenantId}", tenantId);

        var result = await mediator.Send(new UpdateTenantCommand(tenantId, request.Name, request.Description, request.IsActive));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> DeleteTenant(
        Guid tenantId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<TenantEndpointsLogCategory> logger)
    {
        logger.LogInformation("Deleting tenant: {TenantId}", tenantId);

        var result = await mediator.Send(new DeleteTenantCommand(tenantId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
