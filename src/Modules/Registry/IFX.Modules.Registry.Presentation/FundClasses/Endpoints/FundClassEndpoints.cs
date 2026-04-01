using IFX.Modules.Registry.Application.FundClasses.Commands.CreateClass;
using IFX.Modules.Registry.Application.FundClasses.Commands.DeleteClass;
using IFX.Modules.Registry.Application.FundClasses.Commands.UpdateClass;
using IFX.Modules.Registry.Application.FundClasses.Queries.GetClassById;
using IFX.Modules.Registry.Application.FundClasses.Queries.GetClasses;
using IFX.Modules.Registry.Domain.Enums;
using IFX.Modules.Registry.Presentation.FundClasses.Requests;
using IFX.Modules.Registry.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Registry.Presentation.FundClasses.Endpoints;

public sealed class FundClassEndpointsLogCategory { }

public static class FundClassEndpoints
{
    public static async Task<IResult> GetClasses(
        Guid fundId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<FundClassEndpointsLogCategory> logger)
    {
        logger.LogInformation("Accessing classes for fund: {FundId}", fundId);

        var result = await mediator.Send(new GetClassesQuery(fundId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetClassById(
        Guid fundId,
        Guid classId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<FundClassEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting class: {ClassId} for fund: {FundId}", classId, fundId);

        var result = await mediator.Send(new GetClassByIdQuery(classId, fundId));

        if (!result.IsSuccess)
            return Results.NotFound(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreateClass(
        Guid fundId,
        [FromBody] CreateClassRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<FundClassEndpointsLogCategory> logger)
    {
        logger.LogInformation("Creating class: {ClassCode} for fund: {FundId}", request.ClassCode, fundId);

        if (!Enum.TryParse<NavFrequency>(request.NavFrequency, ignoreCase: true, out var navFrequency))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid NAV frequency: {request.NavFrequency}"));

        var result = await mediator.Send(new CreateClassCommand(
            fundId,
            request.ClassCode,
            request.ClassName,
            request.Currency,
            navFrequency,
            request.MinInitialInvestment,
            request.ManagementFeeRate,
            request.PerformanceFeeRate));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UpdateClass(
        Guid fundId,
        Guid classId,
        [FromBody] UpdateClassRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<FundClassEndpointsLogCategory> logger)
    {
        logger.LogInformation("Updating class: {ClassId} for fund: {FundId}", classId, fundId);

        if (!Enum.TryParse<NavFrequency>(request.NavFrequency, ignoreCase: true, out var navFrequency))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid NAV frequency: {request.NavFrequency}"));

        var result = await mediator.Send(new UpdateClassCommand(
            classId,
            fundId,
            request.ClassName,
            request.Currency,
            navFrequency,
            request.MinInitialInvestment,
            request.ManagementFeeRate,
            request.PerformanceFeeRate));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> DeleteClass(
        Guid fundId,
        Guid classId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<FundClassEndpointsLogCategory> logger)
    {
        logger.LogInformation("Closing class: {ClassId} for fund: {FundId}", classId, fundId);

        var result = await mediator.Send(new DeleteClassCommand(classId, fundId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
