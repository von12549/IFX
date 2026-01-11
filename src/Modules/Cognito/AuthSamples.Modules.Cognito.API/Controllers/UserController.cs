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

    /// <summary>
    /// Get current user profile
    /// </summary>
    [HttpGet("profile")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ApiResponse<object>>> GetProfile()
    {
        var subject = User.FindFirst("sub")?.Value;
        if (string.IsNullOrEmpty(subject))
        {
            return Unauthorized(ApiResponse<object>.FailureResponse("Invalid token"));
        }

        var query = new GetUserProfileQuery(subject);
        var result = await _mediator.Send(query);

        if (!result.IsSuccess)
        {
            return NotFound(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    /// <summary>
    /// Update current user profile
    /// </summary>
    [HttpPut("profile")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<ApiResponse<object>>> UpdateProfile(
        [FromBody] UpdateUserProfileRequest request)
    {
        var subject = User.FindFirst("sub")?.Value;
        if (string.IsNullOrEmpty(subject))
        {
            return Unauthorized(ApiResponse<object>.FailureResponse("Invalid token"));
        }

        _logger.LogInformation("User {Subject} updating their profile", subject);

        var command = new UpdateUserProfileCommand(
            subject,
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

    /// <summary>
    /// Get current user login history (paginated)
    /// </summary>
    [HttpGet("login-history")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<ApiResponse<object>>> GetLoginHistory(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
    {
        var subject = User.FindFirst("sub")?.Value;
        if (string.IsNullOrEmpty(subject))
        {
            return Unauthorized(ApiResponse<object>.FailureResponse("Invalid token"));
        }

        var query = new GetUserLoginHistoryQuery(
            subject,
            page,
            pageSize);

        var result = await _mediator.Send(query);

        if (!result.IsSuccess)
        {
            return BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    /// <summary>
    /// Get current user activity log (paginated)
    /// </summary>
    [HttpGet("activity-log")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<ApiResponse<object>>> GetActivityLog(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50)
    {
        var subject = User.FindFirst("sub")?.Value;
        if (string.IsNullOrEmpty(subject))
        {
            return Unauthorized(ApiResponse<object>.FailureResponse("Invalid token"));
        }

        var query = new GetUserActivityLogQuery(
            subject,
            page,
            pageSize);

        var result = await _mediator.Send(query);

        if (!result.IsSuccess)
        {
            return BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    /// <summary>
    /// Sync current user profile from Cognito
    /// </summary>
    [HttpPost("sync")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<ApiResponse<object>>> SyncProfile()
    {
        var subject = User.FindFirst("sub")?.Value;

        if (string.IsNullOrEmpty(subject))
        {
            return Unauthorized(ApiResponse<object>.FailureResponse("Invalid token"));
        }

        var command = new SyncUserCommand(subject);

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
