using IFX.Modules.CRM.Application.Investors.Commands.CreateInvestor;
using IFX.Modules.CRM.Application.Investors.Commands.DeleteInvestor;
using IFX.Modules.CRM.Application.Investors.Commands.UpdateInvestor;
using IFX.Modules.CRM.Application.Investors.Commands.UpdateInvestorKyc;
using IFX.Modules.CRM.Application.Investors.Queries.GetInvestorById;
using IFX.Modules.CRM.Application.Investors.Queries.GetInvestors;
using IFX.Modules.CRM.Domain.Enums;
using IFX.Modules.CRM.Presentation.Investors.Requests;
using IFX.Modules.CRM.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Presentation.Investors.Endpoints;

public sealed class InvestorEndpointsLogCategory { }

public static class InvestorEndpoints
{
    public static async Task<IResult> GetInvestors(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestorEndpointsLogCategory> logger)
    {
        logger.LogInformation("Accessing investor list");

        var result = await mediator.Send(new GetInvestorsQuery());

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetInvestorById(
        Guid investorId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestorEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting investor: {InvestorId}", investorId);

        var result = await mediator.Send(new GetInvestorByIdQuery(investorId));

        if (!result.IsSuccess)
            return Results.NotFound(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreateInvestor(
        [FromBody] CreateInvestorRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestorEndpointsLogCategory> logger)
    {
        logger.LogInformation("Creating investor: {InvestorCode}", request.InvestorCode);

        if (!Enum.TryParse<PartyLegalStructure>(request.LegalStructure, ignoreCase: true, out var legalStructure))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid LegalStructure: '{request.LegalStructure}'."));

        var result = await mediator.Send(new CreateInvestorCommand(request.InvestorCode, request.Name, legalStructure, request.TaxResidencyCountry, request.PartyId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UpdateInvestor(
        Guid investorId,
        [FromBody] UpdateInvestorRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestorEndpointsLogCategory> logger)
    {
        logger.LogInformation("Updating investor: {InvestorId}", investorId);

        var result = await mediator.Send(new UpdateInvestorCommand(investorId, request.Name, request.TaxResidencyCountry, request.TIN, request.GIIN));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UpdateInvestorKyc(
        Guid investorId,
        [FromBody] UpdateInvestorKycRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestorEndpointsLogCategory> logger)
    {
        logger.LogInformation("Updating KYC for investor: {InvestorId}", investorId);

        if (!Enum.TryParse<KycStatus>(request.KycStatus, ignoreCase: true, out var kycStatus))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid KycStatus: '{request.KycStatus}'."));

        var result = await mediator.Send(new UpdateInvestorKycCommand(investorId, kycStatus));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> DeleteInvestor(
        Guid investorId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestorEndpointsLogCategory> logger)
    {
        logger.LogInformation("Closing investor: {InvestorId}", investorId);

        var result = await mediator.Send(new DeleteInvestorCommand(investorId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
