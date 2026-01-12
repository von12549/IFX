using AuthSamples.Modules.Auth.API.Models.Requests;
using AuthSamples.Modules.Auth.API.Models.Responses;
using AuthSamples.Modules.Auth.Application.Commands.UpdateUserProfile;
using AuthSamples.Modules.Auth.Application.Interfaces;
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
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<UserManagementController> _logger;

    public UserManagementController(IMediator mediator, IUnitOfWork unitOfWork, ILogger<UserManagementController> logger)
    {
        _mediator = mediator;
        _unitOfWork = unitOfWork;
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
    [HttpPut("users/{userId}")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ApiResponse<object>>> UpdateUserProfile(
        Guid userId,
        [FromBody] UpdateUserProfileRequest request)
    {
        _logger.LogInformation("Admin updating profile for user: {UserId}", userId);

        // Get user by internal ID
        var user = await _unitOfWork.Users.GetByIdAsync(userId);
        if (user == null)
        {
            return NotFound(ApiResponse<object>.FailureResponse("User not found"));
        }

        // Get the first UserIdentity (for now, users only have one identity from IFX Cognito)
        var identity = user.Identities.FirstOrDefault();
        if (identity == null)
        {
            return NotFound(ApiResponse<object>.FailureResponse("User identity not found"));
        }

        var command = new UpdateUserProfileCommand(
            identity.Issuer,
            identity.Subject.Value,
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
