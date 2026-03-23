using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Application.Users.Commands.AssignDepartmentToUser;
using IFX.Modules.Auth.Application.Users.Commands.AssignRoleGroupsToUser;
using IFX.Modules.Auth.Application.Users.Commands.AssignRolesToUser;
using IFX.Modules.Auth.Application.Users.Commands.AssignTenantToUser;
using IFX.Modules.Auth.Application.Users.Commands.RemoveDepartmentFromUser;
using IFX.Modules.Auth.Application.Users.Commands.RemoveRoleFromUser;
using IFX.Modules.Auth.Application.Users.Commands.RemoveRoleGroupFromUser;
using IFX.Modules.Auth.Application.Users.Commands.RemoveTenantFromUser;
using IFX.Modules.Auth.Application.Users.Commands.UpdateUserProfile;
using IFX.Modules.Auth.Application.Users.Queries.GetAllUsers;
using IFX.Modules.Auth.Application.Users.Queries.GetUserById;
using IFX.Modules.Auth.Presentation.Users.Requests;
using IFX.Modules.Auth.Presentation.Models.Responses;
using IFX.Platform.BackgroundJobs.Abstractions;
using IFX.Platform.Notifications.Abstractions;
using IFX.Platform.Notifications.Abstractions.Models;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Presentation.Users.Endpoints;
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

        var result = await mediator.Send(new GetAllUsersQuery(page, pageSize));

        if (!result.IsSuccess)
        {
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> GetUserById(
        Guid userId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<UserManagementEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin getting user: {UserId}", userId);

        var result = await mediator.Send(new GetUserByIdQuery(userId));

        if (!result.IsSuccess)
            return Results.Json(ApiResponse<object>.FailureResponse(result.Error!), statusCode: StatusCodes.Status404NotFound);

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
                    Subject = "Test Email from IFX",
                    HtmlBody = $"<h1>Hello {userName}!</h1><p>This is a test email sent from IFX.</p><p>If you received this email, your email configuration is working correctly.</p>",
                    PlainTextBody = $"Hello {userName}!\n\nThis is a test email sent from IFX.\n\nIf you received this email, your email configuration is working correctly."
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

    public static async Task<IResult> AssignRolesToUser(
        Guid userId,
        [FromBody] AssignRolesToUserRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<UserManagementEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin assigning roles to user: {UserId}", userId);

        var result = await mediator.Send(new AssignRolesToUserCommand(userId, request.RoleIds));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> RemoveRoleFromUser(
        Guid userId,
        Guid roleId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<UserManagementEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin removing role {RoleId} from user {UserId}", roleId, userId);

        var result = await mediator.Send(new RemoveRoleFromUserCommand(userId, roleId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> AssignRoleGroupsToUser(
        Guid userId,
        [FromBody] AssignRoleGroupsToUserRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<UserManagementEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin assigning role groups to user: {UserId}", userId);

        var result = await mediator.Send(new AssignRoleGroupsToUserCommand(userId, request.RoleGroupIds));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> RemoveRoleGroupFromUser(
        Guid userId,
        Guid roleGroupId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<UserManagementEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin removing role group {RoleGroupId} from user {UserId}", roleGroupId, userId);

        var result = await mediator.Send(new RemoveRoleGroupFromUserCommand(userId, roleGroupId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> AssignTenantToUser(
        Guid userId,
        [FromBody] AssignTenantToUserRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<UserManagementEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin assigning tenant {TenantId} to user {UserId}", request.TenantId, userId);

        var result = await mediator.Send(new AssignTenantToUserCommand(userId, request.TenantId, request.SetAsPrimary));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> RemoveTenantFromUser(
        Guid userId,
        Guid tenantId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<UserManagementEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin removing tenant {TenantId} from user {UserId}", tenantId, userId);

        var result = await mediator.Send(new RemoveTenantFromUserCommand(userId, tenantId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> AssignDepartmentToUser(
        Guid userId,
        [FromBody] AssignDepartmentToUserRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<UserManagementEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin assigning department {DepartmentId} to user {UserId}", request.DepartmentId, userId);

        var result = await mediator.Send(new AssignDepartmentToUserCommand(userId, request.DepartmentId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    public static async Task<IResult> RemoveDepartmentFromUser(
        Guid userId,
        Guid departmentId,
        [FromServices] IMediator mediator,
        [FromServices] ILogger<UserManagementEndpointsLogCategory> logger)
    {
        logger.LogInformation("Admin removing department {DepartmentId} from user {UserId}", departmentId, userId);

        var result = await mediator.Send(new RemoveDepartmentFromUserCommand(userId, departmentId));

        if (!result.IsSuccess)
            return Results.BadRequest(ApiResponse<object>.FailureResponse(result.Error!));

        return Results.Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
