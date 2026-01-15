using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;

namespace AuthSamples.Modules.Auth.Presentation.Endpoints.OAuth;

public static class OAuthEndpointExtensions
{
    public static IEndpointRouteBuilder MapOAuthEndpoints(this IEndpointRouteBuilder builder)
    {
        var group = builder.MapGroup("/api/v1/auth/oauth")
            .WithTags("OAuth")
            ;

        group.MapGet("/authorize", OAuthEndpoints.Authorize)
            .WithName("OAuthAuthorize")
            .WithSummary("Initiate OAuth authorization code flow (redirects to Cognito)")
            .AllowAnonymous()
            .Produces(StatusCodes.Status302Found);

        group.MapGet("/callback", OAuthEndpoints.Callback)
            .WithName("OAuthCallback")
            .WithSummary("Handle OAuth callback and exchange code for tokens")
            .AllowAnonymous()
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status400BadRequest);

        group.MapGet("/userinfo", OAuthEndpoints.UserInfo)
            .WithName("OAuthUserInfo")
            .WithSummary("Get user information from access token")
            .RequireAuthorization()
            .Produces<object>(StatusCodes.Status200OK)
            .Produces<object>(StatusCodes.Status401Unauthorized);

        group.MapGet("/logout", OAuthEndpoints.Logout)
            .WithName("OAuthLogout")
            .WithSummary("Initiate OAuth logout flow (redirects to Cognito)")
            .AllowAnonymous()
            .Produces(StatusCodes.Status302Found);

        group.MapGet("/logout-callback", OAuthEndpoints.LogoutCallback)
            .WithName("OAuthLogoutCallback")
            .WithSummary("Handle OAuth logout callback")
            .AllowAnonymous()
            .Produces<object>(StatusCodes.Status200OK);

        return builder;
    }
}
