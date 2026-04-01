using IFX.Modules.Registry.Application.Funds.Commands.CreateFund;
using IFX.Modules.Registry.Application.Funds.Commands.DeleteFund;
using IFX.Modules.Registry.Application.Funds.Commands.UpdateFund;
using IFX.Modules.Registry.Application.Funds.Queries.GetFundById;
using IFX.Modules.Registry.Application.Funds.Queries.GetFunds;
using IFX.Modules.Registry.Domain.Enums;
using IFX.Modules.Registry.Presentation.Funds.Requests;
using IFX.Modules.Registry.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Presentation.Funds.Endpoints;

public sealed class FundEndpointsLogCategory { }

public static class FundEndpoints
{
    public static async Task<IResult> GetFunds(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<FundEndpointsLogCategory> logger)
    {
        logger.LogInformation("Accessing funds list");

        var result = await mediator.Send(new GetFundsQuery());

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetFundById(
        Guid fundId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<FundEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting fund: {FundId}", fundId);

        var result = await mediator.Send(new GetFundByIdQuery(fundId));

        if (!result.IsSuccess)
            return Results.NotFound(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreateFund(
        [FromBody] CreateFundRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<FundEndpointsLogCategory> logger)
    {
        logger.LogInformation("Creating fund: {FundCode}", request.FundCode);

        if (!Enum.TryParse<FundType>(request.FundType, ignoreCase: true, out var fundType))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid fund type: {request.FundType}"));

        if (!DateOnly.TryParse(request.InceptionDate, out var inceptionDate))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid inception date: {request.InceptionDate}"));

        var result = await mediator.Send(new CreateFundCommand(
            request.FundCode,
            request.FundName,
            fundType,
            request.BaseCurrency,
            inceptionDate));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UpdateFund(
        Guid fundId,
        [FromBody] UpdateFundRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<FundEndpointsLogCategory> logger)
    {
        logger.LogInformation("Updating fund: {FundId}", fundId);

        if (!Enum.TryParse<FundType>(request.FundType, ignoreCase: true, out var fundType))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid fund type: {request.FundType}"));

        var result = await mediator.Send(new UpdateFundCommand(
            fundId,
            request.FundName,
            fundType,
            request.BaseCurrency));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> DeleteFund(
        Guid fundId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<FundEndpointsLogCategory> logger)
    {
        logger.LogInformation("Closing fund: {FundId}", fundId);

        var result = await mediator.Send(new DeleteFundCommand(fundId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
