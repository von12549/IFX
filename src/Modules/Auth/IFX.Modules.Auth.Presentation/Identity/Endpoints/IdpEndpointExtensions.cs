using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace IFX.Modules.Auth.Presentation.Identity.Endpoints;

public static class IdpEndpointExtensions
{
    public static IEndpointRouteBuilder MapIdpEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/idp")
            .WithTags("Identity Provider")
            .RequireAuthorization(policy => policy.RequireRole("Admin"))
            ;

        group.MapGet("/", IdpEndpoints.GetAllIdps)
            .WithName("GetAllIdps")
            .WithSummary("Get all Identity Providers (Admin only)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status403Forbidden);

        group.MapPost("/", IdpEndpoints.CreateIdp)
            .WithName("CreateIdp")
            .WithSummary("Create a new Identity Provider (Admin only)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status403Forbidden);

        group.MapPut("/{idpId}", IdpEndpoints.UpdateIdp)
            .WithName("UpdateIdp")
            .WithSummary("Update an existing Identity Provider (Admin only)")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status403Forbidden);

        return builder;
    }
}
