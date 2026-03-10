using IFX.Modules.Auth.Application.Commands.ConfirmRegistration;
using IFX.Modules.Auth.Application.Commands.LoginUser;
using IFX.Modules.Auth.Application.Commands.LogoutUser;
using IFX.Modules.Auth.Application.Commands.RefreshToken;
using IFX.Modules.Auth.Application.Commands.RegisterUser;
using IFX.Modules.Auth.Application.Commands.RevokeToken;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Presentation.Extensions;
using IFX.Modules.Auth.Presentation.Models.Requests.Auth;
using IFX.Modules.Auth.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Presentation.Endpoints.Auth;

public sealed class AuthEndpointsLogCategory { }

public static class AuthEndpoints
{
    public static async Task<IResult> Register(
        [FromBody] RegisterRequest request,
        [FromServices] IMediator mediator,
        HttpContext httpContext)
    {
        var ipAddress = httpContext.GetIpAddress();

        var command = new RegisterUserCommand(
            request.Email,
            request.Password,
            request.Username,
            request.FirstName,
            request.LastName,
            request.BirthDate.ToString("yyyy-MM-dd"),
            request.PhoneNumber,
            ipAddress);

        var result = await mediator.Send(command);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(new
        {
            Message = "Registration successful. Please check your email for the confirmation code.",
            RequiresConfirmation = result.Value!.RequiresConfirmation
        }));
    }

    public static async Task<IResult> ConfirmRegistration(
        [FromBody] ConfirmRegistrationRequest request,
        [FromServices] IMediator mediator,
        HttpContext httpContext)
    {
        var ipAddress = httpContext.GetIpAddress();

        var command = new ConfirmRegistrationCommand(
            request.Email,
            request.ConfirmationCode,
            ipAddress);

        var result = await mediator.Send(command);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(new
        {
            Message = "Email confirmed successfully. You can now log in."
        }));
    }

    /// <summary>
    /// [Deprecated] Use OAuth 2.0 Authorization Code flow via /api/v1/auth/oauth/authorize instead.
    /// </summary>
    [Obsolete("Use OAuth 2.0 Authorization Code flow via /api/v1/auth/oauth/authorize instead.")]
    public static async Task<IResult> Login(
        [FromBody] LoginRequest request,
        [FromServices] IMediator mediator,
        HttpContext httpContext)
    {
        var ipAddress = httpContext.GetIpAddress();
        var userAgent = httpContext.Request.Headers.UserAgent.ToString();

        var command = new LoginUserCommand(
            request.Email,
            request.Password,
            ipAddress,
            userAgent);

        var result = await mediator.Send(command);

        if (!result.IsSuccess)
        {
            return Results.Json(
                ApiResponse<object>.FailureResponse(result.Error!),
                statusCode: StatusCodes.Status401Unauthorized);
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> RefreshToken(
        [FromBody] RefreshTokenRequest request,
        [FromServices] IMediator mediator,
        [FromServices] IUnitOfWork unitOfWork,
        [FromServices] ILogger<AuthEndpointsLogCategory> logger,
        HttpContext httpContext,
        CancellationToken cancellationToken)
    {
        var ipAddress = httpContext.GetIpAddress();

        // Get primary IdP
        var primaryIdp = await unitOfWork.Idps.GetPrimaryIdpAsync(cancellationToken);
        if (primaryIdp == null)
        {
            logger.LogError("Primary IdP not found or not enabled in database");
            return Results.Json(
                ApiResponse<object>.FailureResponse("System configuration error. Please contact support."),
                statusCode: StatusCodes.Status404NotFound);
        }

        // Query user by email to get Subject
        var user = await unitOfWork.Users.GetByEmailAndIdpAsync(request.Email, primaryIdp.Id, cancellationToken);
        if (user == null)
        {
            logger.LogWarning("User not found for email {Email}", request.Email);
            return Results.Json(
                ApiResponse<object>.FailureResponse("User not found"),
                statusCode: StatusCodes.Status404NotFound);
        }

        // Get the first UserIdentity to extract subject for Cognito refresh
        var identity = user.Identities.FirstOrDefault();
        if (identity == null)
        {
            logger.LogWarning("User identity not found for email {Email}", request.Email);
            return Results.Json(
                ApiResponse<object>.FailureResponse("User identity not found"),
                statusCode: StatusCodes.Status404NotFound);
        }

        var command = new RefreshTokenCommand(
            request.RefreshToken,
            Username: identity.Subject.Value,
            ipAddress);

        var result = await mediator.Send(command, cancellationToken);

        if (!result.IsSuccess)
        {
            logger.LogWarning("Token refresh failed for {Email}: {ErrorMessage}", request.Email, result.Error);
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        logger.LogInformation("Token refreshed successfully for {Email}", request.Email);
        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> RevokeToken(
        [FromBody] RevokeTokenRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<AuthEndpointsLogCategory> logger,
        HttpContext httpContext,
        CancellationToken cancellationToken)
    {
        var ipAddress = httpContext.GetIpAddress();

        var command = new Application.Commands.RevokeToken.RevokeTokenCommand(
            request.RefreshToken,
            Email: null, // Email is optional for revoke
            ipAddress);

        var result = await mediator.Send(command, cancellationToken);

        if (!result.IsSuccess)
        {
            logger.LogWarning("Token revocation failed: {ErrorMessage}", result.Error);
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        logger.LogInformation("Refresh token revoked successfully");
        return Results.Ok(ApiResponse<object>.SuccessResponse(new { Message = "Refresh token revoked successfully" }));
    }

    public static async Task<IResult> Logout(
        [FromServices] IMediator mediator,
        HttpContext httpContext)
    {
        var accessToken = httpContext.Request.Headers.Authorization.ToString().Replace("Bearer ", "");
        var ipAddress = httpContext.GetIpAddress();

        // Extract issuer and subject from JWT claims
        var (issuer, subject) = httpContext.User.GetIssuerAndSubject();

        if (string.IsNullOrEmpty(issuer) || string.IsNullOrEmpty(subject))
        {
            return Results.Json(
                ApiResponse<object>.FailureResponse("Invalid token"),
                statusCode: StatusCodes.Status401Unauthorized);
        }

        var command = new LogoutUserCommand(
            issuer,
            subject,
            accessToken,
            ipAddress);

        var result = await mediator.Send(command);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(new
        {
            Message = "Logged out successfully"
        }));
    }
}
