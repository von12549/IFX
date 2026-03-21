using IFX.Modules.Auth.Application.Identity.Commands.CreateIdp;
using IFX.Modules.Auth.Application.Identity.Commands.UpdateIdp;
using IFX.Modules.Auth.Application.Identity.Interfaces;
using IFX.Modules.Auth.Application.Identity.Queries.GetAllIdps;
using IFX.Modules.Auth.Application.Identity.Queries.GetIdpById;
using IFX.Modules.Auth.Presentation.Identity.Requests;
using IFX.Modules.Auth.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Presentation.Identity.Endpoints;

public sealed class IdpEndpointsLogCategory { }
public static class IdpEndpoints
{
    public static async Task<IResult> GetAllIdps(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<IdpEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin accessing Identity Providers list");

        var query = new GetAllIdpsQuery();
        var result = await mediator.Send(query);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetIdpById(
        Guid idpId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<IdpEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting Identity Provider: {IdpId}", idpId);

        var result = await mediator.Send(new GetIdpByIdQuery(idpId));

        if (!result.IsSuccess)
            return Results.Json(ApiResponse<object>.FailureResponse(result.Error!), statusCode: StatusCodes.Status404NotFound);

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreateIdp(
        [FromBody] CreateIdpRequest request,
        [FromServices] IMediator mediator,
        [FromServices] IIdpCacheInvalidator cacheInvalidator,
        [FromServices] ILogger<IdpEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin creating new Identity Provider: {Name}", request.Name);

        var command = new CreateIdpCommand(
            request.Name,
            request.Issuer,
            request.Authority,
            request.Description,
            request.LoginUrl,
            request.IdpType,
            request.IsPrimary,
            request.Enabled,
            request.AutoProvisionEnabled,
            request.ExpectedAudiences,
            request.AllowedAlgs,
            request.RequiredScopes,
            request.ClaimMapping,
            request.ClockSkewSeconds);

        var result = await mediator.Send(command);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        // Invalidate IdP configuration cache after successful creation
        cacheInvalidator.InvalidateCache();

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UpdateIdp(
        Guid idpId,
        [FromBody] UpdateIdpRequest request,
        [FromServices] IMediator mediator,
        [FromServices] IIdpCacheInvalidator cacheInvalidator,
        [FromServices] ILogger<IdpEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin updating Identity Provider: {IdpId}", idpId);

        var command = new UpdateIdpCommand(
            idpId,
            request.Name,
            request.Issuer,
            request.Authority,
            request.Description,
            request.LoginUrl,
            request.IdpType,
            request.IsPrimary,
            request.Enabled,
            request.AutoProvisionEnabled,
            request.ExpectedAudiences,
            request.AllowedAlgs,
            request.RequiredScopes,
            request.ClaimMapping,
            request.ClockSkewSeconds);

        var result = await mediator.Send(command);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        // Invalidate IdP configuration cache after successful update
        cacheInvalidator.InvalidateCache();

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
