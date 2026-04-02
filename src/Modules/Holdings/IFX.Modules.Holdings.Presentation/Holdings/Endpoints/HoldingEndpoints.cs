using IFX.Modules.Holdings.Application.Queries.GetHoldingById;
using IFX.Modules.Holdings.Application.Queries.GetHoldings;
using IFX.Modules.Holdings.Application.Queries.GetHoldingsByClass;
using IFX.Modules.Holdings.Application.Queries.GetHoldingsByInvestor;
using IFX.Modules.Holdings.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Holdings.Presentation.Holdings.Endpoints;

public sealed class HoldingEndpointsLogCategory { }

public static class HoldingEndpoints
{
    public static async Task<IResult> GetHoldings(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<HoldingEndpointsLogCategory> logger)
    {
        logger.LogInformation("Listing holdings");
        var result = await mediator.Send(new GetHoldingsQuery());
        if (!result.IsSuccess) return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetHoldingById(
        Guid holdingId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<HoldingEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting holding {HoldingId}", holdingId);
        var result = await mediator.Send(new GetHoldingByIdQuery(holdingId));
        if (!result.IsSuccess) return Results.NotFound(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetHoldingsByInvestor(
        Guid investorId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<HoldingEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting holdings for investor {InvestorId}", investorId);
        var result = await mediator.Send(new GetHoldingsByInvestorQuery(investorId));
        if (!result.IsSuccess) return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetHoldingsByClass(
        Guid fundId,
        Guid classId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<HoldingEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting holdings for class {ClassId}", classId);
        var result = await mediator.Send(new GetHoldingsByClassQuery(classId));
        if (!result.IsSuccess) return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
