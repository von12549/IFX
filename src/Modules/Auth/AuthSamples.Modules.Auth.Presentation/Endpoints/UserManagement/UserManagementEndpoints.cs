using AuthSamples.Modules.Auth.Application.Commands.UpdateUserProfile;
using AuthSamples.Modules.Auth.Application.Interfaces;
using AuthSamples.Modules.Auth.Application.Queries.GetAllUsers;
using AuthSamples.Modules.Auth.Presentation.Models.Requests.User;
using AuthSamples.Modules.Auth.Presentation.Models.Responses;
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
}
