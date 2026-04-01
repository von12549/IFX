using IFX.Modules.CRM.Application.Investors.Queries.GetInvestorsByParty;
using IFX.Modules.CRM.Application.Parties.Commands.CreateParty;
using IFX.Modules.CRM.Application.Parties.Commands.DeleteParty;
using IFX.Modules.CRM.Application.Parties.Commands.UpdateParty;
using IFX.Modules.CRM.Application.Parties.Queries.GetParties;
using IFX.Modules.CRM.Application.Parties.Queries.GetPartyById;
using IFX.Modules.CRM.Application.Relationships.Commands.LinkInvestorToParty;
using IFX.Modules.CRM.Application.Relationships.Commands.UnlinkInvestorFromParty;
using IFX.Modules.CRM.Domain.Enums;
using IFX.Modules.CRM.Presentation.Models.Responses;
using IFX.Modules.CRM.Presentation.Parties.Requests;
using IFX.Modules.CRM.Presentation.Relationships.Requests;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Presentation.Parties.Endpoints;

public sealed class PartyEndpointsLogCategory { }

public static class PartyEndpoints
{
    public static async Task<IResult> GetParties(
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PartyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Accessing party list");

        var result = await mediator.Send(new GetPartiesQuery());

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetPartyById(
        Guid partyId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PartyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting party: {PartyId}", partyId);

        var result = await mediator.Send(new GetPartyByIdQuery(partyId));

        if (!result.IsSuccess)
            return Results.NotFound(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreateParty(
        [FromBody] CreatePartyRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PartyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Creating party: {PartyCode}", request.PartyCode);

        if (!Enum.TryParse<PartyType>(request.Type, ignoreCase: true, out var partyType))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid PartyType: '{request.Type}'."));

        var result = await mediator.Send(new CreatePartyCommand(request.PartyCode, request.Name, partyType));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UpdateParty(
        Guid partyId,
        [FromBody] UpdatePartyRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PartyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Updating party: {PartyId}", partyId);

        if (!Enum.TryParse<PartyType>(request.Type, ignoreCase: true, out var partyType))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid PartyType: '{request.Type}'."));

        var result = await mediator.Send(new UpdatePartyCommand(partyId, request.Name, partyType));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> DeleteParty(
        Guid partyId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PartyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Closing party: {PartyId}", partyId);

        var result = await mediator.Send(new DeletePartyCommand(partyId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetInvestorsByParty(
        Guid partyId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PartyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting investors for party: {PartyId}", partyId);

        var result = await mediator.Send(new GetInvestorsByPartyQuery(partyId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> LinkInvestorToParty(
        Guid partyId,
        Guid investorId,
        [FromBody] LinkInvestorRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PartyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Linking investor {InvestorId} to party {PartyId}", investorId, partyId);

        if (!Enum.TryParse<RelationshipType>(request.RelationshipType, ignoreCase: true, out var relationshipType))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid RelationshipType: '{request.RelationshipType}'."));

        if (!DateOnly.TryParse(request.EffectiveDate, out var effectiveDate))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid EffectiveDate: '{request.EffectiveDate}'. Expected format: yyyy-MM-dd."));

        var result = await mediator.Send(new LinkInvestorToPartyCommand(partyId, investorId, relationshipType, effectiveDate));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UnlinkInvestorFromParty(
        Guid partyId,
        Guid investorId,
        [FromQuery] string relationshipType,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PartyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Unlinking investor {InvestorId} from party {PartyId}", investorId, partyId);

        if (!Enum.TryParse<RelationshipType>(relationshipType, ignoreCase: true, out var relType))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid RelationshipType: '{relationshipType}'."));

        var result = await mediator.Send(new UnlinkInvestorFromPartyCommand(partyId, investorId, relType));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
