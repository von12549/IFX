using IFX.Modules.CRM.Application.Investors.Queries.GetInvestorsByParty;
using IFX.Modules.CRM.Application.Parties.Commands.AssignPartyRole;
using IFX.Modules.CRM.Application.Parties.Commands.CreateParty;
using IFX.Modules.CRM.Application.Parties.Commands.CreatePartyRelationship;
using IFX.Modules.CRM.Application.Parties.Commands.DeleteParty;
using IFX.Modules.CRM.Application.Parties.Commands.ExpirePartyRelationship;
using IFX.Modules.CRM.Application.Parties.Commands.LinkUserToParty;
using IFX.Modules.CRM.Application.Parties.Commands.RemovePartyRole;
using IFX.Modules.CRM.Application.Parties.Commands.UnlinkUserFromParty;
using IFX.Modules.CRM.Application.Parties.Commands.UpdateParty;
using IFX.Modules.CRM.Application.Parties.Queries.GetParties;
using IFX.Modules.CRM.Application.Parties.Queries.GetPartyById;
using IFX.Modules.CRM.Application.Parties.Queries.GetPartyForUser;
using IFX.Modules.CRM.Application.Parties.Queries.GetPartyRelationships;
using IFX.Modules.CRM.Application.Parties.Queries.GetPartyRoles;
using IFX.Modules.CRM.Domain.Enums;
using IFX.Modules.CRM.Presentation.Models.Responses;
using IFX.Modules.CRM.Presentation.Parties.Requests;
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

        if (!Enum.TryParse<PartyLegalStructure>(request.Type, ignoreCase: true, out var legalStructure))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid LegalStructure: '{request.Type}'."));

        var result = await mediator.Send(new CreatePartyCommand(request.PartyCode, request.Name, legalStructure));

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

        if (!Enum.TryParse<PartyLegalStructure>(request.Type, ignoreCase: true, out var legalStructure))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid LegalStructure: '{request.Type}'."));

        var result = await mediator.Send(new UpdatePartyCommand(partyId, request.Name, legalStructure));

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

    public static async Task<IResult> GetPartyRoles(
        Guid partyId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PartyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting roles for party {PartyId}", partyId);

        var result = await mediator.Send(new GetPartyRolesQuery(partyId));

        if (!result.IsSuccess)
            return Results.NotFound(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> AssignPartyRole(
        Guid partyId,
        string role,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PartyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Assigning role {Role} to party {PartyId}", role, partyId);

        if (!Enum.TryParse<PartyFunctionalRole>(role, ignoreCase: true, out var functionalRole))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid role: '{role}'."));

        var result = await mediator.Send(new AssignPartyRoleCommand(partyId, functionalRole));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> RemovePartyRole(
        Guid partyId,
        string role,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PartyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Removing role {Role} from party {PartyId}", role, partyId);

        if (!Enum.TryParse<PartyFunctionalRole>(role, ignoreCase: true, out var functionalRole))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid role: '{role}'."));

        var result = await mediator.Send(new RemovePartyRoleCommand(partyId, functionalRole));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetPartyRelationships(
        Guid partyId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PartyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting relationships for party {PartyId}", partyId);

        var result = await mediator.Send(new GetPartyRelationshipsQuery(partyId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetPartyForUser(
        Guid userId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PartyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Getting party for user {UserId}", userId);

        var result = await mediator.Send(new GetPartyForUserQuery(userId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> CreatePartyRelationship(
        Guid partyId,
        [FromBody] CreatePartyRelationshipRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PartyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Creating relationship from party {PartyId} to party {ToPartyId}", partyId, request.ToPartyId);

        if (!Enum.TryParse<PartyRelationshipType>(request.RelationshipType, ignoreCase: true, out var relationshipType))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid RelationshipType: '{request.RelationshipType}'."));

        if (!DateOnly.TryParse(request.EffectiveDate, out var effectiveDate))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid EffectiveDate: '{request.EffectiveDate}'. Expected format: yyyy-MM-dd."));

        var result = await mediator.Send(new CreatePartyRelationshipCommand(partyId, request.ToPartyId, relationshipType, effectiveDate));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> ExpirePartyRelationship(
        Guid partyId,
        Guid relationshipId,
        [FromBody] ExpirePartyRelationshipRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PartyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Expiring relationship {RelationshipId} for party {PartyId}", relationshipId, partyId);

        if (!DateOnly.TryParse(request.ExpiryDate, out var expiryDate))
            return Results.BadRequest(ApiResponse<object>.FailureResponse($"Invalid ExpiryDate: '{request.ExpiryDate}'. Expected format: yyyy-MM-dd."));

        var result = await mediator.Send(new ExpirePartyRelationshipCommand(relationshipId, expiryDate));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> LinkUserToParty(
        Guid partyId,
        Guid userId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PartyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Linking user {UserId} to party {PartyId}", userId, partyId);

        var result = await mediator.Send(new LinkUserToPartyCommand(userId, partyId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UnlinkUserFromParty(
        Guid partyId,
        Guid userId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<PartyEndpointsLogCategory> logger)
    {
        logger.LogInformation("Unlinking user {UserId} from party {PartyId}", userId, partyId);

        var result = await mediator.Send(new UnlinkUserFromPartyCommand(userId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
