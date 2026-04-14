using IFX.Modules.CRM.Application.Investors.Commands.CreateInvestor;
using IFX.Modules.CRM.Application.Investors.Commands.DeleteInvestor;
using IFX.Modules.CRM.Application.Investors.Commands.UpdateInvestor;
using IFX.Modules.CRM.Application.Investors.Commands.UpdateInvestorAml;
using IFX.Modules.CRM.Application.Investors.Commands.UpdateInvestorKyc;
using IFX.Modules.CRM.Application.Investors.Queries.GetInvestorById;
using IFX.Modules.CRM.Application.Investors.Queries.GetInvestors;
using IFX.Modules.CRM.Application.Investors.Queries.GetInvestorDocuments;
using IFX.Modules.CRM.Application.Investors.Commands.AddInvestorDocument;
using IFX.Modules.CRM.Application.Investors.Commands.RemoveInvestorDocument;
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

    public static async Task<IResult> UpdateInvestorAml(
        Guid investorId,
        [FromBody] UpdateInvestorAmlRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestorEndpointsLogCategory> logger)
    {
        logger.LogInformation("Updating AML for investor: {InvestorId}", investorId);

        if (!Enum.TryParse<AmlStatus>(request.AmlStatus, ignoreCase: true, out var amlStatus))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid AmlStatus: '{request.AmlStatus}'."));

        var result = await mediator.Send(new UpdateInvestorAmlCommand(
            investorId, amlStatus, request.AmlGatewayReference,
            request.IsPEP, request.PepDetails, request.SourceOfWealth,
            request.UnresolvedPepCount, request.UnresolvedSanctionCount, request.UnresolvedAdverseMediaCount));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetInvestorDocuments(
        Guid investorId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestorEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting documents for investor: {InvestorId}", investorId);

        var result = await mediator.Send(new GetInvestorDocumentsQuery(investorId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> AddInvestorDocument(
        Guid investorId,
        [FromBody] AddInvestorDocumentRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestorEndpointsLogCategory> logger)
    {
        logger.LogInformation("Adding document for investor: {InvestorId}", investorId);

        if (!Enum.TryParse<DocumentType>(request.DocumentType, ignoreCase: true, out var documentType))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid DocumentType: '{request.DocumentType}'."));

        DateOnly? issueDate = null;
        if (request.IssueDate != null && !DateOnly.TryParse(request.IssueDate, out var parsedIssue))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid IssueDate: '{request.IssueDate}'. Expected format: yyyy-MM-dd."));
        else if (request.IssueDate != null)
            issueDate = DateOnly.Parse(request.IssueDate);

        DateOnly? expiryDate = null;
        if (request.ExpiryDate != null && !DateOnly.TryParse(request.ExpiryDate, out var parsedExpiry))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid ExpiryDate: '{request.ExpiryDate}'. Expected format: yyyy-MM-dd."));
        else if (request.ExpiryDate != null)
            expiryDate = DateOnly.Parse(request.ExpiryDate);

        var result = await mediator.Send(new AddInvestorDocumentCommand(
            investorId, documentType, request.DocumentNumber, request.IssueCountry,
            request.IssueState, issueDate, expiryDate));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> RemoveInvestorDocument(
        Guid investorId,
        Guid documentId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestorEndpointsLogCategory> logger)
    {
        logger.LogInformation("Removing document {DocumentId} from investor {InvestorId}", documentId, investorId);

        var result = await mediator.Send(new RemoveInvestorDocumentCommand(investorId, documentId));

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
