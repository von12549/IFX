using IFX.Modules.CRM.Presentation.Investors.Endpoints;
using IFX.Modules.CRM.Presentation.Parties.Endpoints;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Presentation.Extensions;

public static class EndpointExtensions
{
    public static IEndpointRouteBuilder MapPartyEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/party")
            .WithTags("Party")
            .RequireAuthorization();

        group.MapGet("/",
            (IServiceProvider services) =>
                PartyEndpoints.GetParties(
                    services.GetRequiredService<MediatR.IMediator>(),
                    services.GetRequiredService<ILogger<PartyEndpointsLogCategory>>()))
            .WithName("GetParties")
            .RequirePermission("Party:list")
            .WithSummary("Get all parties for the current tenant (from X-Tenant-Id header)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/{partyId}", PartyEndpoints.GetPartyById)
            .WithName("GetPartyById")
            .RequirePermission("Party:read")
            .WithSummary("Get a party by ID")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapPost("/", PartyEndpoints.CreateParty)
            .WithName("CreateParty")
            .RequirePermission("Party:create")
            .WithSummary("Create a new party")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{partyId}", PartyEndpoints.UpdateParty)
            .WithName("UpdateParty")
            .RequirePermission("Party:update")
            .WithSummary("Update an existing party")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{partyId}", PartyEndpoints.DeleteParty)
            .WithName("DeleteParty")
            .RequirePermission("Party:delete")
            .WithSummary("Close a party (soft delete)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/{partyId}/investors",
            (Guid partyId, IServiceProvider services) =>
                PartyEndpoints.GetInvestorsByParty(
                    partyId,
                    services.GetRequiredService<MediatR.IMediator>(),
                    services.GetRequiredService<ILogger<PartyEndpointsLogCategory>>()))
            .WithName("GetInvestorsByParty")
            .RequirePermission("Party:read")
            .WithSummary("Get all investors linked to a party")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/{partyId}/investors/{investorId}", PartyEndpoints.LinkInvestorToParty)
            .WithName("LinkInvestorToParty")
            .RequirePermission("PartyInvestor:link")
            .WithSummary("Link an investor to a party with a relationship type")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{partyId}/investors/{investorId}", PartyEndpoints.UnlinkInvestorFromParty)
            .WithName("UnlinkInvestorFromParty")
            .RequirePermission("PartyInvestor:unlink")
            .WithSummary("Unlink an investor from a party (requires ?relationshipType=)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }

    public static IEndpointRouteBuilder MapInvestorEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/investor")
            .WithTags("Investor")
            .RequireAuthorization();

        group.MapGet("/",
            (IServiceProvider services) =>
                InvestorEndpoints.GetInvestors(
                    services.GetRequiredService<MediatR.IMediator>(),
                    services.GetRequiredService<ILogger<InvestorEndpointsLogCategory>>()))
            .WithName("GetInvestors")
            .RequirePermission("Investor:list")
            .WithSummary("Get all investors for the current tenant (from X-Tenant-Id header)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/{investorId}", InvestorEndpoints.GetInvestorById)
            .WithName("GetInvestorById")
            .RequirePermission("Investor:read")
            .WithSummary("Get an investor by ID")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapPost("/", InvestorEndpoints.CreateInvestor)
            .WithName("CreateInvestor")
            .RequirePermission("Investor:create")
            .WithSummary("Create a new investor")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{investorId}", InvestorEndpoints.UpdateInvestor)
            .WithName("UpdateInvestor")
            .RequirePermission("Investor:update")
            .WithSummary("Update an existing investor")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{investorId}/kyc", InvestorEndpoints.UpdateInvestorKyc)
            .WithName("UpdateInvestorKyc")
            .RequirePermission("Investor:update")
            .WithSummary("Update KYC status for an investor")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{investorId}", InvestorEndpoints.DeleteInvestor)
            .WithName("DeleteInvestor")
            .RequirePermission("Investor:delete")
            .WithSummary("Close an investor (soft delete)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }
}
