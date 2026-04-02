using IFX.Modules.Holdings.Presentation.Holdings.Endpoints;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace IFX.Modules.Holdings.Presentation.Extensions;

public static class EndpointExtensions
{
    public static IEndpointRouteBuilder MapHoldingEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1").WithTags("Holdings");

        group.MapGet("/holding", HoldingEndpoints.GetHoldings)
            .RequireAuthorization()
            .RequirePermission("Holding:list");

        group.MapGet("/holding/{holdingId:guid}", HoldingEndpoints.GetHoldingById)
            .RequireAuthorization()
            .RequirePermission("Holding:read");

        group.MapGet("/investor/{investorId:guid}/holdings", HoldingEndpoints.GetHoldingsByInvestor)
            .RequireAuthorization()
            .RequirePermission("Holding:list");

        group.MapGet("/fund/{fundId:guid}/class/{classId:guid}/holdings", HoldingEndpoints.GetHoldingsByClass)
            .RequireAuthorization()
            .RequirePermission("Holding:list");

        return builder;
    }
}
