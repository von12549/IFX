using IFX.Modules.Auth.Presentation.Extensions;
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
            .RequireAuthorization();

        group.MapGet("/{idpId}", IdpEndpoints.GetIdpById)
            .WithName("GetIdpById")
            .RequirePermission("Idp:read")
            .WithSummary("Get an Identity Provider by ID")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapGet("/", IdpEndpoints.GetAllIdps)
            .WithName("GetAllIdps")
            .RequirePermission("Idp:list")
            .WithSummary("Get all Identity Providers")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
;

        group.MapPost("/", IdpEndpoints.CreateIdp)
            .WithName("CreateIdp")
            .RequirePermission("Idp:create")
            .WithSummary("Create a new Identity Provider")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
;

        group.MapPut("/{idpId}", IdpEndpoints.UpdateIdp)
            .WithName("UpdateIdp")
            .RequirePermission("Idp:update")
            .WithSummary("Update an existing Identity Provider")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status401Unauthorized)
;

        return builder;
    }
}
