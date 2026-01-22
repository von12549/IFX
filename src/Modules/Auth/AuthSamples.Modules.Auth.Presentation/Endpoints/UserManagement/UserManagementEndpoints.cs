using AuthSamples.Modules.Auth.Application.Commands.UpdateUserProfile;
using AuthSamples.Modules.Auth.Application.Interfaces;
using AuthSamples.Modules.Auth.Application.Queries.GetAllUsers;
using AuthSamples.Modules.Auth.Presentation.Models.Requests.User;
using AuthSamples.Modules.Auth.Presentation.Models.Responses;
using AuthSamples.Platform.BackgroundJobs.Abstractions;
using AuthSamples.Platform.Notifications.Abstractions;
using AuthSamples.Platform.Notifications.Abstractions.Models;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Auth.Presentation.Endpoints.UserManagement;
public sealed class UserManagementEndpointsLogCategory { }
public static class UserManagementEndpoints
{
    public static async Task<IResult> GetAllUsers(
        [FromQuery] int page,
        [FromQuery] int pageSize,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<UserManagementEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin accessing user list. Page: {Page}, PageSize: {PageSize}", page, pageSize);

        var query = new GetAllUsersQuery(page, pageSize);
        var result = await mediator.Send(query);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> UpdateUserProfile(
        Guid userId,
        [FromBody] UpdateUserProfileRequest request,
        [FromServices] IMediator mediator,
        [FromServices] IUnitOfWork unitOfWork,
        [FromServices] ILogger<UserManagementEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin updating profile for user: {UserId}", userId);

        // Get user by internal ID
        var user = await unitOfWork.Users.GetByIdAsync(userId);
        if (user == null)
        {
            return Results.Json(
                ApiResponse<object>.FailureResponse("User not found"),
                statusCode: StatusCodes.Status404NotFound);
        }

        // Get the first UserIdentity (for now, users only have one identity from IFX Cognito)
        var identity = user.Identities.FirstOrDefault();
        if (identity == null)
        {
            return Results.Json(
                ApiResponse<object>.FailureResponse("User identity not found"),
                statusCode: StatusCodes.Status404NotFound);
        }

        var command = new UpdateUserProfileCommand(
            identity.Issuer,
            identity.Subject.Value,
            request.Username,
            request.FirstName,
            request.LastName,
            request.PhoneNumber);

        var result = await mediator.Send(command);

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> SendTestEmail(
        Guid userId,
        [FromServices] IUnitOfWork unitOfWork,
        [FromServices] IBackgroundJobService backgroundJobService,
        [FromServices] ILogger<UserManagementEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin sending test email to user: {UserId}", userId);

        // Get user by internal ID
        var user = await unitOfWork.Users.GetByIdAsync(userId);
        if (user == null)
        {
            return Results.Json(
                ApiResponse<object>.FailureResponse("User not found"),
                statusCode: StatusCodes.Status404NotFound);
        }

        // Get user's email from identity
        var identity = user.Identities.FirstOrDefault();
        if (identity == null || string.IsNullOrEmpty(identity.Email?.Value))
        {
            return Results.Json(
                ApiResponse<object>.FailureResponse("User email not found"),
                statusCode: StatusCodes.Status400BadRequest);
        }

        var userEmail = identity.Email.Value;
        var userName = user.DisplayName ?? "User";

        // Enqueue email job on "email" queue
        var jobId = backgroundJobService.Enqueue<IEmailService>(
            service => service.SendEmailAsync(
                new EmailMessage
                {
                    To = userEmail,
                    ToName = userName,
                    Subject = "Test Email from AuthSamples",
                    HtmlBody = $"<h1>Hello {userName}!</h1><p>This is a test email sent from AuthSamples.</p><p>If you received this email, your email configuration is working correctly.</p>",
                    PlainTextBody = $"Hello {userName}!\n\nThis is a test email sent from AuthSamples.\n\nIf you received this email, your email configuration is working correctly."
                },
                default),
            "email");

        logger.LogInformation("Test email job {JobId} enqueued for user {UserId} ({Email})", jobId, userId, userEmail);

        return Results.Ok(ApiResponse<object>.SuccessResponse(new
        {
            Message = "Test email job enqueued successfully",
            JobId = jobId,
            Email = userEmail
        }));
    }
}
