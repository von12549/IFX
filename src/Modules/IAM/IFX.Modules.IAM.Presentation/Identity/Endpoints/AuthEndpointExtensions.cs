using IFX.BuildingBlocks.Application.Context;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace IFX.Modules.IAM.Presentation.Identity.Endpoints;

public static class AuthEndpointExtensions
{
    public static IEndpointRouteBuilder MapAuthEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/auth")
            .WithTags("Authentication")
            .WithMetadata(ExecutionScopeRequirement.Public)
            ;

        group.MapPost("/register", AuthEndpoints.Register)
            .WithName("Register")
            .WithSummary("Register a new user account")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest);

        group.MapPost("/confirm", AuthEndpoints.ConfirmRegistration)
            .WithName("ConfirmRegistration")
            .WithSummary("Confirm user email with verification code")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest);

        group.MapPost("/login", AuthEndpoints.Login)
            .WithName("Login")
            .WithSummary("[Deprecated] Authenticate user with email and password. Use /api/v1/auth/oauth/authorize for new integrations.")
            .WithDescription("This endpoint is deprecated. For new integrations, use the OAuth 2.0 Authorization Code flow via /api/v1/auth/oauth/authorize which provides better security with PKCE and access to /userinfo endpoint.")
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapPost("/refresh", AuthEndpoints.RefreshToken)
            .WithName("RefreshToken")
            .WithSummary("Refresh access token using a valid refresh token")
            .AllowAnonymous()
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest)
            .Produces<object>(StatusCodes.Status404NotFound);

        group.MapPost("/revoke", AuthEndpoints.RevokeToken)
            .WithName("RevokeToken")
            .WithSummary("Revoke a refresh token to invalidate it")
            .AllowAnonymous()
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest);

        group.MapPost("/logout", AuthEndpoints.Logout)
            .WithName("Logout")
            .WithSummary("Logout user and invalidate session")
            .RequireAuthorization()
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized)
            .Produces<object>(StatusCodes.Status400BadRequest);

        return builder;
    }
}
