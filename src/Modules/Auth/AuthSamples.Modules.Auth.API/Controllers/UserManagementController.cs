using AuthSamples.Modules.Auth.API.Models.Requests;
using AuthSamples.Modules.Auth.API.Models.Responses;
using AuthSamples.Modules.Auth.Application.Commands.UpdateUserProfile;
using AuthSamples.Modules.Auth.Application.Queries.GetAllUsers;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AuthSamples.Modules.Auth.API.Controllers;

[Authorize(Roles = "Admin")]
[ApiController]
[Route("api/v1/[controller]")]
public class UserManagementController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ILogger<UserManagementController> _logger;

    public UserManagementController(IMediator mediator, ILogger<UserManagementController> logger)
    {
        _mediator = mediator;
        _logger = logger;
    }

    /// <summary>
    /// Get all users (Admin only, paginated)
    /// </summary>
    [HttpGet("users")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<ApiResponse<object>>> GetAllUsers(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50)
    {
        _logger.LogInformation("Admin accessing user list. Page: {Page}, PageSize: {PageSize}", page, pageSize);

        var query = new GetAllUsersQuery(page, pageSize);
        var result = await _mediator.Send(query);

        if (!result.IsSuccess)
        {
            return BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    /// <summary>
    /// Update any user's profile (Admin only)
    /// </summary>
    [HttpPut("users/{subject}")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<ApiResponse<object>>> UpdateUserProfile(
        string subject,
        [FromBody] UpdateUserProfileRequest request)
    {
        _logger.LogInformation("Admin updating profile for user: {Subject}", subject);

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
}
