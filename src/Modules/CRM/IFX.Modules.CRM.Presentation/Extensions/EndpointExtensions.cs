using IFX.Modules.CRM.Presentation.InvestmentAccounts.Endpoints;
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

        group.MapGet("/{partyId}/roles", PartyEndpoints.GetPartyRoles)
            .WithName("GetPartyRoles")
            .RequirePermission("Party:read")
            .WithSummary("Get all functional roles assigned to a party")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapPost("/{partyId}/roles/{role}", PartyEndpoints.AssignPartyRole)
            .WithName("AssignPartyRole")
            .RequirePermission("Party:update")
            .WithSummary("Assign a functional role to a party")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{partyId}/roles/{role}", PartyEndpoints.RemovePartyRole)
            .WithName("RemovePartyRole")
            .RequirePermission("Party:update")
            .WithSummary("Remove a functional role from a party")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/{partyId}/relationships", PartyEndpoints.GetPartyRelationships)
            .WithName("GetPartyRelationships")
            .RequirePermission("Party:read")
            .WithSummary("Get all relationships for a party")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/{partyId}/relationships", PartyEndpoints.CreatePartyRelationship)
            .WithName("CreatePartyRelationship")
            .RequirePermission("Party:update")
            .WithSummary("Create a relationship between two parties")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{partyId}/relationships/{relationshipId}/expire", PartyEndpoints.ExpirePartyRelationship)
            .WithName("ExpirePartyRelationship")
            .RequirePermission("Party:update")
            .WithSummary("Set the expiry date on a party relationship")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/{partyId}/users/{userId}", PartyEndpoints.LinkUserToParty)
            .WithName("LinkUserToParty")
            .RequirePermission("Party:update")
            .WithSummary("Link a user account to a party")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{partyId}/users/{userId}", PartyEndpoints.UnlinkUserFromParty)
            .WithName("UnlinkUserFromParty")
            .RequirePermission("Party:update")
            .WithSummary("Unlink a user account from a party")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/user/{userId}/party", PartyEndpoints.GetPartyForUser)
            .WithName("GetPartyForUser")
            .RequirePermission("Party:read")
            .WithSummary("Get the party linked to a user")
            .Produces<object>(StatusCodes.Status200OK)
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

        group.MapPut("/{investorId}/aml", InvestorEndpoints.UpdateInvestorAml)
            .WithName("UpdateInvestorAml")
            .RequirePermission("Investor:update")
            .WithSummary("Update AML status for an investor")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/{investorId}/documents", InvestorEndpoints.GetInvestorDocuments)
            .WithName("GetInvestorDocuments")
            .RequirePermission("Investor:read")
            .WithSummary("Get all documents for an investor")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/{investorId}/documents", InvestorEndpoints.AddInvestorDocument)
            .WithName("AddInvestorDocument")
            .RequirePermission("Investor:update")
            .WithSummary("Add an identity document to an investor")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{investorId}/documents/{documentId}", InvestorEndpoints.RemoveInvestorDocument)
            .WithName("RemoveInvestorDocument")
            .RequirePermission("Investor:update")
            .WithSummary("Remove an identity document from an investor")
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

    public static IEndpointRouteBuilder MapInvestmentAccountEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/investment-account")
            .WithTags("InvestmentAccount")
            .RequireAuthorization();

        group.MapGet("/",
            (IServiceProvider services) =>
                InvestmentAccountEndpoints.GetInvestmentAccounts(
                    services.GetRequiredService<MediatR.IMediator>(),
                    services.GetRequiredService<ILogger<InvestmentAccountEndpointsLogCategory>>()))
            .WithName("GetInvestmentAccounts")
            .RequirePermission("InvestmentAccount:list")
            .WithSummary("Get all investment accounts for the current tenant")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/{id}", InvestmentAccountEndpoints.GetInvestmentAccountById)
            .WithName("GetInvestmentAccountById")
            .RequirePermission("InvestmentAccount:read")
            .WithSummary("Get an investment account by ID")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapPost("/", InvestmentAccountEndpoints.CreateInvestmentAccount)
            .WithName("CreateInvestmentAccount")
            .RequirePermission("InvestmentAccount:create")
            .WithSummary("Create a new investment account")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPut("/{id}", InvestmentAccountEndpoints.UpdateInvestmentAccount)
            .WithName("UpdateInvestmentAccount")
            .RequirePermission("InvestmentAccount:update")
            .WithSummary("Update an investment account")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{id}", InvestmentAccountEndpoints.DeleteInvestmentAccount)
            .WithName("DeleteInvestmentAccount")
            .RequirePermission("InvestmentAccount:delete")
            .WithSummary("Close an investment account (soft delete)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/{id}/parties/{partyId}", InvestmentAccountEndpoints.LinkPartyToInvestmentAccount)
            .WithName("LinkPartyToInvestmentAccount")
            .RequirePermission("InvestmentAccount:update")
            .WithSummary("Link a party to an investment account")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{id}/parties/{partyId}", InvestmentAccountEndpoints.UnlinkPartyFromInvestmentAccount)
            .WithName("UnlinkPartyFromInvestmentAccount")
            .RequirePermission("InvestmentAccount:update")
            .WithSummary("Unlink a party from an investment account")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/{id}/advisors", InvestmentAccountEndpoints.GetAdvisorsForInvestmentAccount)
            .WithName("GetAdvisorsForInvestmentAccount")
            .RequirePermission("InvestmentAccount:read")
            .WithSummary("Get all advisors linked to an investment account")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/{id}/advisors/{advisorPartyId}", InvestmentAccountEndpoints.LinkAdvisorToInvestmentAccount)
            .WithName("LinkAdvisorToInvestmentAccount")
            .RequirePermission("InvestmentAccount:update")
            .WithSummary("Link an advisor party to an investment account")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapDelete("/{id}/advisors/{advisorPartyId}", InvestmentAccountEndpoints.UnlinkAdvisorFromInvestmentAccount)
            .WithName("UnlinkAdvisorFromInvestmentAccount")
            .RequirePermission("InvestmentAccount:update")
            .WithSummary("Unlink an advisor party from an investment account")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        return builder;
    }
}
