using AuthSamples.Modules.Auth.Application.Commands.SyncUser;
using AuthSamples.Modules.Auth.Application.Commands.UpdateUserProfile;
using AuthSamples.Modules.Auth.Application.Queries.GetUserActivityLog;
using AuthSamples.Modules.Auth.Application.Queries.GetUserLoginHistory;
using AuthSamples.Modules.Auth.Application.Queries.GetUserProfile;
using AuthSamples.Modules.Auth.Presentation.Extensions;
using AuthSamples.Modules.Auth.Presentation.Models.Requests.User;
using AuthSamples.Modules.Auth.Presentation.Models.Responses;
using MediatR;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Modules.Auth.Presentation.Endpoints.User;

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

    public static async Task<IResult> UpdateProfile(
        [FromBody] UpdateUserProfileRequest request,
        [FromServices] IMediator mediator,
        [FromServices] ILogger logger,
        HttpContext httpContext)
    {
        var (issuer, subject) = httpContext.User.GetIssuerAndSubject();
        if (string.IsNullOrEmpty(issuer) || string.IsNullOrEmpty(subject))
        {
            return Results.Json(
                ApiResponse<object>.FailureResponse("Invalid token"),
                statusCode: StatusCodes.Status401Unauthorized);
        }

        logger.LogInformation("User {Issuer}/{Subject} updating their profile", issuer, subject);

        var command = new UpdateUserProfileCommand(
            issuer,
            subject,
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
