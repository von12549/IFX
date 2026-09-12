using IFX.Modules.IAM.Application.Identity.Commands.ResendEmailVerification;
using IFX.Modules.IAM.Application.Identity.Commands.SendEmailVerification;
using IFX.Modules.IAM.Application.Identity.Commands.VerifyEmail;
using IFX.Modules.IAM.Application.Identity.Interfaces;
using IFX.Modules.IAM.Application.Identity.Ports;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Presentation.Extensions;
using IFX.Modules.IAM.Presentation.Users.Requests;
using IFX.Modules.IAM.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Presentation.Users.Endpoints;

public sealed class EmailVerificationEndpointsLogCategory { }

public static class EmailVerificationEndpoints
{
    private const int TokenValidityMinutes = 60;

    /// <summary>
    /// Public endpoint to verify email with token or code
    /// </summary>
    public static async Task<IResult> VerifyEmail(
        [FromBody] VerifyEmailRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<EmailVerificationEndpointsLogCategory> logger,
        HttpContext httpContext)
    {
        logger.LogInformation("Email verification attempt for UserIdentityId: {UserIdentityId}", request.UserIdentityId);

        var ipAddress = httpContext.Connection.RemoteIpAddress?.ToString();

        var command = new VerifyEmailCommand(
            request.UserIdentityId,
            request.Token,
            request.Code,
            ipAddress);

        var result = await mediator.Send(command);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(new
        {
            result.Value!.Success,
            result.Value.Message
        }));
    }

    /// <summary>
    /// Public endpoint to verify email from link (GET request)
    /// </summary>
    public static async Task<IResult> VerifyEmailFromLink(
        [FromQuery] string? token,
        [FromQuery] Guid? uid,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<EmailVerificationEndpointsLogCategory> logger,
        HttpContext httpContext)
    {
        if (string.IsNullOrEmpty(token) || !uid.HasValue)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(
                "Missing required parameters. Both 'token' and 'uid' are required."));
        }

        logger.LogInformation("Email verification from link for UserIdentityId: {UserIdentityId}", uid.Value);

        var ipAddress = httpContext.Connection.RemoteIpAddress?.ToString();

        var command = new VerifyEmailCommand(
            uid.Value,
            token,
            null, // No code for link-based verification
            ipAddress);

        var result = await mediator.Send(command);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(new
        {
            result.Value!.Success,
            result.Value.Message
        }));
    }

    /// <summary>
    /// Authenticated endpoint to request email verification for current user
    /// </summary>
    public static async Task<IResult> SendVerification(
        [FromServices] IMediator mediator,
        [FromServices] IUnitOfWork unitOfWork,
        [FromServices] IIdentityEmailJobScheduler emailJobs,
        [FromServices] IEmailVerificationService emailVerificationService,
        [FromServices] IConfiguration configuration,
        [FromServices] ILogger<EmailVerificationEndpointsLogCategory> logger,
        HttpContext httpContext)
    {
        var (issuer, subject) = httpContext.User.GetIssuerAndSubject();
        if (string.IsNullOrEmpty(issuer) || string.IsNullOrEmpty(subject))
        {
            return Results.Json(
                ApiResponse<object>.FailureResponse("Invalid token"),
                statusCode: StatusCodes.Status401Unauthorized);
        }

        var ipAddress = httpContext.Connection.RemoteIpAddress?.ToString();

        // Get the user identity
        var userIdentity = await unitOfWork.UserIdentities.GetByIssuerAndSubjectAsync(issuer, subject);
        if (userIdentity == null)
        {
            return Results.Json(
                ApiResponse<object>.FailureResponse("User not found"),
                statusCode: StatusCodes.Status404NotFound);
        }

        logger.LogInformation("Sending email verification for user: {UserId}", userIdentity.UserId);

        // Send the command to create verification token
        var command = new SendEmailVerificationCommand(userIdentity.Id, ipAddress);
        var result = await mediator.Send(command);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        // Get user info for email
        var user = await unitOfWork.Users.GetByIdAsync(userIdentity.UserId);
        var userName = user?.DisplayName ?? "User";

        // Build verification link
        var baseUrl = configuration["EmailVerification:VerificationBaseUrl"] ?? "http://localhost:5010/api/v1/auth/email/verify";
        var verificationLink = $"{baseUrl}?token={result.Value!.Token}&uid={result.Value.UserIdentityId}";

        // Build email content
        var htmlBody = emailVerificationService.BuildVerificationEmailHtml(
            userName, result.Value.Code, verificationLink, TokenValidityMinutes);
        var plainTextBody = emailVerificationService.BuildVerificationEmailPlainText(
            userName, result.Value.Code, verificationLink, TokenValidityMinutes);

        // Enqueue email job
        var jobId = emailJobs.Enqueue(new IdentityEmailJob(
            result.Value.Email, userName, "Verify your email address", htmlBody, plainTextBody));

        logger.LogInformation(
            "Email verification job {JobId} enqueued for user {UserId} ({Email})",
            jobId, userIdentity.UserId, result.Value.Email);

        return Results.Ok(ApiResponse<object>.SuccessResponse(new
        {
            Message = "Verification email sent successfully",
            ExpiresAt = result.Value.ExpiresAt
        }));
    }

    /// <summary>
    /// Authenticated endpoint to resend email verification for current user
    /// </summary>
    public static async Task<IResult> ResendVerification(
        [FromServices] IMediator mediator,
        [FromServices] IUnitOfWork unitOfWork,
        [FromServices] IIdentityEmailJobScheduler emailJobs,
        [FromServices] IEmailVerificationService emailVerificationService,
        [FromServices] IConfiguration configuration,
        [FromServices] ILogger<EmailVerificationEndpointsLogCategory> logger,
        HttpContext httpContext)
    {
        var (issuer, subject) = httpContext.User.GetIssuerAndSubject();
        if (string.IsNullOrEmpty(issuer) || string.IsNullOrEmpty(subject))
        {
            return Results.Json(
                ApiResponse<object>.FailureResponse("Invalid token"),
                statusCode: StatusCodes.Status401Unauthorized);
        }

        var ipAddress = httpContext.Connection.RemoteIpAddress?.ToString();

        // Get the user identity
        var userIdentity = await unitOfWork.UserIdentities.GetByIssuerAndSubjectAsync(issuer, subject);
        if (userIdentity == null)
        {
            return Results.Json(
                ApiResponse<object>.FailureResponse("User not found"),
                statusCode: StatusCodes.Status404NotFound);
        }

        logger.LogInformation("Resending email verification for user: {UserId}", userIdentity.UserId);

        // Send the resend command (includes rate limiting)
        var command = new ResendEmailVerificationCommand(userIdentity.Id, ipAddress);
        var result = await mediator.Send(command);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        // Get user info for email
        var user = await unitOfWork.Users.GetByIdAsync(userIdentity.UserId);
        var userName = user?.DisplayName ?? "User";

        // Build verification link
        var baseUrl = configuration["EmailVerification:VerificationBaseUrl"] ?? "http://localhost:5010/api/v1/auth/email/verify";
        var verificationLink = $"{baseUrl}?token={result.Value!.Token}&uid={result.Value.UserIdentityId}";

        // Build email content
        var htmlBody = emailVerificationService.BuildVerificationEmailHtml(
            userName, result.Value.Code, verificationLink, TokenValidityMinutes);
        var plainTextBody = emailVerificationService.BuildVerificationEmailPlainText(
            userName, result.Value.Code, verificationLink, TokenValidityMinutes);

        // Enqueue email job
        var jobId = emailJobs.Enqueue(new IdentityEmailJob(
            result.Value.Email, userName, "Verify your email address", htmlBody, plainTextBody));

        logger.LogInformation(
            "Email verification resend job {JobId} enqueued for user {UserId} ({Email})",
            jobId, userIdentity.UserId, result.Value.Email);

        return Results.Ok(ApiResponse<object>.SuccessResponse(new
        {
            Message = "Verification email resent successfully",
            ExpiresAt = result.Value.ExpiresAt
        }));
    }

    /// <summary>
    /// Get email verification status for current user
    /// </summary>
    public static async Task<IResult> GetVerificationStatus(
        [FromServices] IUnitOfWork unitOfWork,
        [FromServices] ILogger<EmailVerificationEndpointsLogCategory> logger,
        HttpContext httpContext)
    {
        var (issuer, subject) = httpContext.User.GetIssuerAndSubject();
        if (string.IsNullOrEmpty(issuer) || string.IsNullOrEmpty(subject))
        {
            return Results.Json(
                ApiResponse<object>.FailureResponse("Invalid token"),
                statusCode: StatusCodes.Status401Unauthorized);
        }

        // Get the user identity
        var userIdentity = await unitOfWork.UserIdentities.GetByIssuerAndSubjectAsync(issuer, subject);
        if (userIdentity == null)
        {
            return Results.Json(
                ApiResponse<object>.FailureResponse("User not found"),
                statusCode: StatusCodes.Status404NotFound);
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(new
        {
            Email = userIdentity.Email?.Value,
            EmailVerified = userIdentity.EmailVerified
        }));
    }
}
