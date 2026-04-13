using IFX.Modules.CRM.Application.InvestmentAccounts.Commands.CreateInvestmentAccount;
using IFX.Modules.CRM.Application.InvestmentAccounts.Commands.DeleteInvestmentAccount;
using IFX.Modules.CRM.Application.InvestmentAccounts.Commands.LinkAdvisorToInvestmentAccount;
using IFX.Modules.CRM.Application.InvestmentAccounts.Commands.LinkPartyToInvestmentAccount;
using IFX.Modules.CRM.Application.InvestmentAccounts.Commands.UnlinkAdvisorFromInvestmentAccount;
using IFX.Modules.CRM.Application.InvestmentAccounts.Commands.UnlinkPartyFromInvestmentAccount;
using IFX.Modules.CRM.Application.InvestmentAccounts.Commands.UpdateInvestmentAccount;
using IFX.Modules.CRM.Application.InvestmentAccounts.Queries.GetInvestmentAccountById;
using IFX.Modules.CRM.Application.InvestmentAccounts.Queries.GetInvestmentAccounts;
using IFX.Modules.CRM.Domain.Enums;
using IFX.Modules.CRM.Presentation.InvestmentAccounts.Requests;
using IFX.Modules.CRM.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Presentation.InvestmentAccounts.Endpoints;

public sealed class InvestmentAccountEndpointsLogCategory { }

public static class InvestmentAccountEndpoints
{
    public static async Task<IResult> GetInvestmentAccounts(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestmentAccountEndpointsLogCategory> logger)
    {
        logger.LogInformation("Accessing investment account list");

        var result = await mediator.Send(new GetInvestmentAccountsQuery());

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetInvestmentAccountById(
        Guid id,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestmentAccountEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting investment account {Id}", id);

        var result = await mediator.Send(new GetInvestmentAccountByIdQuery(id));

        if (!result.IsSuccess)
            return Results.NotFound(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreateInvestmentAccount(
        [FromBody] CreateInvestmentAccountRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestmentAccountEndpointsLogCategory> logger)
    {
        logger.LogInformation("Creating investment account {AccountNumber}", request.AccountNumber);

        if (!Enum.TryParse<InvestmentAccountType>(request.AccountType, ignoreCase: true, out var accountType))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid AccountType: '{request.AccountType}'."));

        DateOnly? certificateDate = null;
        if (request.CertificateDate != null && !DateOnly.TryParse(request.CertificateDate, out var parsedDate))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid CertificateDate: '{request.CertificateDate}'. Expected format: yyyy-MM-dd."));
        else if (request.CertificateDate != null)
            certificateDate = DateOnly.Parse(request.CertificateDate);

        var result = await mediator.Send(new CreateInvestmentAccountCommand(request.AccountNumber, accountType, certificateDate));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UpdateInvestmentAccount(
        Guid id,
        [FromBody] UpdateInvestmentAccountRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestmentAccountEndpointsLogCategory> logger)
    {
        logger.LogInformation("Updating investment account {Id}", id);

        if (!Enum.TryParse<InvestmentAccountType>(request.AccountType, ignoreCase: true, out var accountType))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid AccountType: '{request.AccountType}'."));

        DateOnly? certificateDate = null;
        if (request.CertificateDate != null && !DateOnly.TryParse(request.CertificateDate, out var parsedDate))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid CertificateDate: '{request.CertificateDate}'. Expected format: yyyy-MM-dd."));
        else if (request.CertificateDate != null)
            certificateDate = DateOnly.Parse(request.CertificateDate);

        var result = await mediator.Send(new UpdateInvestmentAccountCommand(id, request.AccountNumber, accountType, certificateDate));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> DeleteInvestmentAccount(
        Guid id,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestmentAccountEndpointsLogCategory> logger)
    {
        logger.LogInformation("Closing investment account {Id}", id);

        var result = await mediator.Send(new DeleteInvestmentAccountCommand(id));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> LinkPartyToInvestmentAccount(
        Guid id,
        Guid partyId,
        [FromBody] LinkPartyToInvestmentAccountRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestmentAccountEndpointsLogCategory> logger)
    {
        logger.LogInformation("Linking party {PartyId} to investment account {Id}", partyId, id);

        if (!Enum.TryParse<InvestmentAccountRelationshipType>(request.RelationshipType, ignoreCase: true, out var relationshipType))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid RelationshipType: '{request.RelationshipType}'."));

        if (!DateOnly.TryParse(request.EffectiveDate, out var effectiveDate))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid EffectiveDate: '{request.EffectiveDate}'. Expected format: yyyy-MM-dd."));

        var result = await mediator.Send(new LinkPartyToInvestmentAccountCommand(id, partyId, relationshipType, effectiveDate, request.OwnershipPercentage, request.LinkOrder));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UnlinkPartyFromInvestmentAccount(
        Guid id,
        Guid partyId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestmentAccountEndpointsLogCategory> logger)
    {
        logger.LogInformation("Unlinking party {PartyId} from investment account {Id}", partyId, id);

        var result = await mediator.Send(new UnlinkPartyFromInvestmentAccountCommand(id, partyId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> LinkAdvisorToInvestmentAccount(
        Guid id,
        Guid advisorPartyId,
        [FromBody] LinkAdvisorToInvestmentAccountRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestmentAccountEndpointsLogCategory> logger)
    {
        logger.LogInformation("Linking advisor {AdvisorPartyId} to investment account {Id}", advisorPartyId, id);

        if (!DateOnly.TryParse(request.EffectiveDate, out var effectiveDate))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid EffectiveDate: '{request.EffectiveDate}'. Expected format: yyyy-MM-dd."));

        var result = await mediator.Send(new LinkAdvisorToInvestmentAccountCommand(id, advisorPartyId, effectiveDate, request.RebateRate));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UnlinkAdvisorFromInvestmentAccount(
        Guid id,
        Guid advisorPartyId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<InvestmentAccountEndpointsLogCategory> logger)
    {
        logger.LogInformation("Unlinking advisor {AdvisorPartyId} from investment account {Id}", advisorPartyId, id);

        var result = await mediator.Send(new UnlinkAdvisorFromInvestmentAccountCommand(id, advisorPartyId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
