using IFX.Modules.Auth.Application.Commands.SendEmailVerification;
using IFX.Modules.Auth.Application.Commands.SyncUser;
using IFX.Modules.Auth.Application.Commands.UpdateUserProfile;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Application.Queries.GetUserActivityLog;
using IFX.Modules.Auth.Application.Queries.GetUserLoginHistory;
using IFX.Modules.Auth.Application.Queries.GetUserProfile;
using IFX.Modules.Auth.Presentation.Extensions;
using IFX.Modules.Auth.Presentation.Models.Requests.User;
using IFX.Modules.Auth.Presentation.Models.Responses;
using IFX.Platform.BackgroundJobs.Abstractions;
using IFX.Platform.Notifications.Abstractions;
using IFX.Platform.Notifications.Abstractions.Models;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Presentation.Endpoints.User;
public sealed class UserEndpointsLogCategory { }
public static class UserEndpoints
{
    public static async Task<IResult> GetProfile(
        [FromServices] IMediator mediator,
        HttpContext httpContext)
    {
        var (issuer, subject) = httpContext.User.GetIssuerAndSubject();
        if (string.IsNullOrEmpty(issuer) || string.IsNullOrEmpty(subject))
        {
            return Results.Json(
                ApiResponse<object>.FailureResponse("Invalid token"),
                statusCode: StatusCodes.Status401Unauthorized);
        }

        var query = new GetUserProfileQuery(issuer, subject);
        var result = await mediator.Send(query);

        if (!result.IsSuccess)
        {
            return Results.Json(
                ApiResponse<object>.FailureResponse(result.Error!),
                statusCode: StatusCodes.Status404NotFound);
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    private const int TokenValidityMinutes = 60;

    public static async Task<IResult> UpdateProfile(
        [FromBody] UpdateUserProfileRequest request,
        [FromServices] IMediator mediator,
        [FromServices] IBackgroundJobService backgroundJobService,
        [FromServices] IEmailVerificationService emailVerificationService,
        [FromServices] IConfiguration configuration,
        [FromServices] ILogger<UserEndpointsLogCategory> logger,
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

        logger.LogInformation("User {Issuer}/{Subject} updating their profile", issuer, subject);

        var command = new UpdateUserProfileCommand(
            issuer,
            subject,
            request.Username,
            request.FirstName,
            request.LastName,
            request.PhoneNumber,
            request.Email,
            ipAddress);

        var result = await mediator.Send(command);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        // If email changed, trigger email verification
        string? verificationMessage = null;
        if (result.Value!.RequiresEmailVerification && result.Value.UserIdentityId.HasValue)
        {
            var sendVerificationCommand = new SendEmailVerificationCommand(
                result.Value.UserIdentityId.Value,
                ipAddress);

            var verificationResult = await mediator.Send(sendVerificationCommand);

            if (verificationResult.IsSuccess)
            {
                // Build verification link
                var baseUrl = configuration["EmailVerification:VerificationBaseUrl"] ?? "http://localhost:5000/api/v1/auth/email/verify";
                var verificationLink = $"{baseUrl}?token={verificationResult.Value!.Token}&uid={verificationResult.Value.UserIdentityId}";

                // Get user display name
                var userName = result.Value.Profile.DisplayName ?? "User";

                // Build email content
                var htmlBody = emailVerificationService.BuildVerificationEmailHtml(
                    userName, verificationResult.Value.Code, verificationLink, TokenValidityMinutes);
                var plainTextBody = emailVerificationService.BuildVerificationEmailPlainText(
                    userName, verificationResult.Value.Code, verificationLink, TokenValidityMinutes);

                // Enqueue email job
                var jobId = backgroundJobService.Enqueue<IEmailService>(
                    service => service.SendEmailAsync(
                        new EmailMessage
                        {
                            To = verificationResult.Value.Email,
                            ToName = userName,
                            Subject = "Verify your new email address",
                            HtmlBody = htmlBody,
                            PlainTextBody = plainTextBody
                        },
                        default),
                    "email");

                logger.LogInformation(
                    "Email verification job {JobId} enqueued after email change for user {Issuer}/{Subject}",
                    jobId, issuer, subject);

                verificationMessage = "A verification email has been sent to your new email address.";
            }
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(new
        {
            Profile = result.Value.Profile,
            EmailChanged = result.Value.EmailChanged,
            VerificationMessage = verificationMessage
        }));
    }

    public static async Task<IResult> GetLoginHistory(
        [FromQuery] int page,
        [FromQuery] int pageSize,
        [FromServices] IMediator mediator,
        HttpContext httpContext)
    {
        var (issuer, subject) = httpContext.User.GetIssuerAndSubject();
        if (string.IsNullOrEmpty(issuer) || string.IsNullOrEmpty(subject))
        {
            return Results.Json(
                ApiResponse<object>.FailureResponse("Invalid token"),
                statusCode: StatusCodes.Status401Unauthorized);
        }

        var query = new GetUserLoginHistoryQuery(
            issuer,
            subject,
            page,
            pageSize);

        var result = await mediator.Send(query);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetActivityLog(
        [FromQuery] int page,
        [FromQuery] int pageSize,
        [FromServices] IMediator mediator,
        HttpContext httpContext)
    {
        var (issuer, subject) = httpContext.User.GetIssuerAndSubject();
        if (string.IsNullOrEmpty(issuer) || string.IsNullOrEmpty(subject))
        {
            return Results.Json(
                ApiResponse<object>.FailureResponse("Invalid token"),
                statusCode: StatusCodes.Status401Unauthorized);
        }

        var query = new GetUserActivityLogQuery(
            issuer,
            subject,
            page,
            pageSize);

        var result = await mediator.Send(query);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> SyncProfile(
        [FromServices] IMediator mediator,
        HttpContext httpContext)
    {
        var (issuer, subject) = httpContext.User.GetIssuerAndSubject();
        if (string.IsNullOrEmpty(issuer) || string.IsNullOrEmpty(subject))
        {
            return Results.Json(
                ApiResponse<object>.FailureResponse("Invalid token"),
                statusCode: StatusCodes.Status401Unauthorized);
        }

        var command = new SyncUserCommand(issuer, subject);

        var result = await mediator.Send(command);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(new
        {
            Message = "User profile synced successfully",
            User = result.Value
        }));
    }
}
