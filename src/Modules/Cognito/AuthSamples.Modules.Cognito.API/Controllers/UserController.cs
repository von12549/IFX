using AuthSamples.Modules.Cognito.API.Models.Requests;
using AuthSamples.Modules.Cognito.API.Models.Responses;
using AuthSamples.Modules.Cognito.Application.Commands.SyncUser;
using AuthSamples.Modules.Cognito.Application.Commands.UpdateUserProfile;
using AuthSamples.Modules.Cognito.Application.Queries.GetUserActivityLog;
using AuthSamples.Modules.Cognito.Application.Queries.GetUserLoginHistory;
using AuthSamples.Modules.Cognito.Application.Queries.GetUserProfile;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AuthSamples.Modules.Cognito.API.Controllers;

[Authorize]
[ApiController]
[Route("api/v1/[controller]")]
public class UserController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ILogger<UserController> _logger;

    public UserController(IMediator mediator, ILogger<UserController> logger)
    {
        _mediator = mediator;
        _logger = logger;
    }

    [HttpGet("profile")]
    public async Task<ActionResult<ApiResponse<object>>> GetProfile()
    {
        var cognitoUserId = User.FindFirst("sub")?.Value;
        if (string.IsNullOrEmpty(cognitoUserId))
        {
            return Unauthorized(ApiResponse<object>.FailureResponse("Invalid token"));
        }

        var query = new GetUserProfileQuery(cognitoUserId);
        var result = await _mediator.Send(query);

        if (!result.IsSuccess)
        {
            return NotFound(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    [HttpPut("profile")]
    public async Task<ActionResult<ApiResponse<object>>> UpdateProfile(
        [FromBody] UpdateUserProfileRequest request)
    {
        var cognitoUserId = User.FindFirst("sub")?.Value;
        if (string.IsNullOrEmpty(cognitoUserId))
        {
            return Unauthorized(ApiResponse<object>.FailureResponse("Invalid token"));
        }

        _logger.LogInformation("User {CognitoUserId} updating their profile", cognitoUserId);

        var command = new UpdateUserProfileCommand(
            cognitoUserId,
            request.Username,
            request.FirstName,
            request.LastName,
            request.PhoneNumber);

        var result = await _mediator.Send(command);

        if (!result.IsSuccess)
        {
            return BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    [HttpGet("login-history")]
    public async Task<ActionResult<ApiResponse<object>>> GetLoginHistory(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        var cognitoUserId = User.FindFirst("sub")?.Value;
        if (string.IsNullOrEmpty(cognitoUserId))
        {
            return Unauthorized(ApiResponse<object>.FailureResponse("Invalid token"));
        }

        var query = new GetUserLoginHistoryQuery(
            cognitoUserId,
            page,
            pageSize);

        var result = await _mediator.Send(query);

        if (!result.IsSuccess)
        {
            return BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    [HttpGet("activity-log")]
    public async Task<ActionResult<ApiResponse<object>>> GetActivityLog(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50)
    {
        var cognitoUserId = User.FindFirst("sub")?.Value;
        if (string.IsNullOrEmpty(cognitoUserId))
        {
            return Unauthorized(ApiResponse<object>.FailureResponse("Invalid token"));
        }

        var query = new GetUserActivityLogQuery(
            cognitoUserId,
            page,
            pageSize);

        var result = await _mediator.Send(query);

        if (!result.IsSuccess)
        {
            return BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    [HttpPost("sync")]
    public async Task<ActionResult<ApiResponse<object>>> SyncProfile()
    {
        var cognitoUserId = User.FindFirst("sub")?.Value;

        if (string.IsNullOrEmpty(cognitoUserId))
        {
            return Unauthorized(ApiResponse<object>.FailureResponse("Invalid token"));
        }

        var command = new SyncUserCommand(cognitoUserId);

        var result = await _mediator.Send(command);

        if (!result.IsSuccess)
        {
            return BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(new
        {
            Message = "User profile synced successfully",
            User = result.Value
        }));
    }
}
