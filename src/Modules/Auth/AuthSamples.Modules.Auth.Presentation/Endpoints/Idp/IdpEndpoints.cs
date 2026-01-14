using AuthSamples.Modules.Auth.Application.Commands.CreateIdp;
using AuthSamples.Modules.Auth.Application.Commands.UpdateIdp;
using AuthSamples.Modules.Auth.Application.Queries.GetAllIdps;
using AuthSamples.Modules.Auth.Presentation.Models.Requests.Idp;
using AuthSamples.Modules.Auth.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Auth.Presentation.Endpoints.Idp;

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

    public static async Task<IResult> CreateIdp(
        [FromBody] CreateIdpRequest request,
        [FromServices] IMediator mediator,
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

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UpdateIdp(
        Guid idpId,
        [FromBody] UpdateIdpRequest request,
        [FromServices] IMediator mediator,
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

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
