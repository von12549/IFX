using AuthSamples.Modules.Auth.Application.Interfaces;
using AuthSamples.Modules.Auth.Presentation.Models.Responses;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Auth.Presentation.Endpoints.OAuth;

public sealed class OAuthEndpointsLogCategory { }

/// <summary>
/// OAuth 2.0 Authorization Code flow endpoints for Cognito Managed Login
/// </summary>
public static class OAuthEndpoints
{
    /// <summary>
    /// Initiates OAuth authorization flow by redirecting to Cognito Hosted UI
    /// </summary>
    /// <param name="redirect_uri">Optional custom redirect URI</param>
    /// <param name="response_mode">Set to "json" to return URL instead of redirecting (for SPAs)</param>
    public static IResult Authorize(
        [FromServices] IOidcAuthService oidcService,
        [FromServices] ILogger<OAuthEndpointsLogCategory> logger,
        [FromQuery] string? redirect_uri = null,
        [FromQuery] string? response_mode = null)
    {
        try
        {
            var authUrl = oidcService.BuildAuthorizationUrl(redirect_uri);

            logger.LogInformation("Initiating OAuth flow with state {State}", authUrl.State);

            // Return JSON for SPA clients
            if (string.Equals(response_mode, "json", StringComparison.OrdinalIgnoreCase))
            {
                return Results.Ok(ApiResponse<object>.SuccessResponse(new
                {
                    AuthorizationUrl = authUrl.Url,
                    State = authUrl.State
                }));
            }

            // Redirect to Cognito Hosted UI (default)
            return Results.Redirect(authUrl.Url);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error initiating OAuth authorization");
            return Results.Json(
                ApiResponse<object>.FailureResponse("Failed to initiate authorization"),
                statusCode: StatusCodes.Status500InternalServerError);
        }
    }

    /// <summary>
    /// Handles OAuth callback from Cognito, exchanges code for tokens
    /// </summary>
    public static async Task<IResult> Callback(
        [FromServices] IOidcAuthService oidcService,
        [FromServices] ILogger<OAuthEndpointsLogCategory> logger,
        [FromQuery] string? code = null,
        [FromQuery] string? state = null,
        [FromQuery] string? error = null,
        [FromQuery] string? error_description = null)
    {
        // Handle error response from IdP
        if (!string.IsNullOrEmpty(error))
        {
            logger.LogWarning("OAuth callback received error: {Error} - {Description}", error, error_description);
            return Results.Json(
                ApiResponse<object>.FailureResponse(error_description ?? error),
                statusCode: StatusCodes.Status400BadRequest);
        }

        // Validate required parameters
        if (string.IsNullOrEmpty(code) || string.IsNullOrEmpty(state))
        {
            logger.LogWarning("OAuth callback missing required parameters: code={HasCode}, state={HasState}",
                !string.IsNullOrEmpty(code), !string.IsNullOrEmpty(state));
            return Results.Json(
                ApiResponse<object>.FailureResponse("Missing required parameters"),
                statusCode: StatusCodes.Status400BadRequest);
        }

        try
        {
            // Exchange authorization code for tokens
            var tokenResult = await oidcService.ExchangeCodeForTokensAsync(code, state);

            if (!tokenResult.Success)
            {
                logger.LogWarning("Token exchange failed: {Error} - {Description}",
                    tokenResult.Error, tokenResult.ErrorDescription);
                return Results.Json(
                    ApiResponse<object>.FailureResponse(tokenResult.ErrorDescription ?? tokenResult.Error ?? "Token exchange failed"),
                    statusCode: StatusCodes.Status400BadRequest);
            }

            logger.LogInformation("Successfully completed OAuth callback, tokens issued");

            // Return tokens as JSON response
            return Results.Ok(ApiResponse<object>.SuccessResponse(new
            {
                AccessToken = tokenResult.AccessToken,
                IdToken = tokenResult.IdToken,
                RefreshToken = tokenResult.RefreshToken,
                ExpiresIn = tokenResult.ExpiresIn,
                TokenType = tokenResult.TokenType
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error processing OAuth callback");
            return Results.Json(
                ApiResponse<object>.FailureResponse("Failed to process authorization callback"),
                statusCode: StatusCodes.Status500InternalServerError);
        }
    }

    /// <summary>
    /// Gets user information using access token
    /// </summary>
    public static async Task<IResult> UserInfo(
        [FromServices] IOidcAuthService oidcService,
        [FromServices] ILogger<OAuthEndpointsLogCategory> logger,
        HttpContext httpContext)
    {
        try
        {
            var accessToken = httpContext.Request.Headers.Authorization.ToString().Replace("Bearer ", "");

            if (string.IsNullOrEmpty(accessToken))
            {
                return Results.Json(
                    ApiResponse<object>.FailureResponse("Access token required"),
                    statusCode: StatusCodes.Status401Unauthorized);
            }

            var userInfo = await oidcService.GetUserInfoAsync(accessToken);

            logger.LogInformation("Retrieved user info for subject {Subject}", userInfo.Subject);

            return Results.Ok(ApiResponse<object>.SuccessResponse(new
            {
                Sub = userInfo.Subject,
                Email = userInfo.Email,
                EmailVerified = userInfo.EmailVerified,
                Name = userInfo.Name,
                GivenName = userInfo.GivenName,
                FamilyName = userInfo.FamilyName,
                PreferredUsername = userInfo.PreferredUsername,
                PhoneNumber = userInfo.PhoneNumber,
                PhoneNumberVerified = userInfo.PhoneNumberVerified
            }));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error getting user info");
            return Results.Json(
                ApiResponse<object>.FailureResponse("Failed to get user information"),
                statusCode: StatusCodes.Status500InternalServerError);
        }
    }

    /// <summary>
    /// Initiates logout flow via Cognito
    /// </summary>
    public static IResult Logout(
        [FromServices] IOidcAuthService oidcService,
        [FromServices] ILogger<OAuthEndpointsLogCategory> logger,
        HttpContext httpContext,
        [FromQuery] string? post_logout_redirect_uri = null)
    {
        try
        {
            // Get ID token for logout hint (optional)
            var idToken = httpContext.Request.Headers["X-Id-Token"].ToString();

            var logoutUrl = oidcService.BuildLogoutUrl(
                idTokenHint: string.IsNullOrEmpty(idToken) ? null : idToken,
                postLogoutRedirectUri: post_logout_redirect_uri);

            logger.LogInformation("Initiating OAuth logout");

            return Results.Redirect(logoutUrl);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error initiating OAuth logout");
            return Results.Json(
                ApiResponse<object>.FailureResponse("Failed to initiate logout"),
                statusCode: StatusCodes.Status500InternalServerError);
        }
    }

    /// <summary>
    /// Handles logout callback (optional endpoint for post-logout actions)
    /// </summary>
    public static IResult LogoutCallback(
        [FromServices] ILogger<OAuthEndpointsLogCategory> logger)
    {
        logger.LogInformation("Logout callback received");

        return Results.Ok(ApiResponse<object>.SuccessResponse(new
        {
            Message = "Logged out successfully"
        }));
    }
}
