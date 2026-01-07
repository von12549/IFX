using AuthSamples.Modules.Cognito.API.Models.Requests;
using AuthSamples.Modules.Cognito.API.Models.Responses;
using AuthSamples.Modules.Cognito.Application.Commands.UpdateUserProfile;
using AuthSamples.Modules.Cognito.Application.Queries.GetAllUsers;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AuthSamples.Modules.Cognito.API.Controllers;

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

    [HttpGet("users")]
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

    [HttpPut("users/{cognitoUserId}")]
    public async Task<ActionResult<ApiResponse<object>>> UpdateUserProfile(
        string cognitoUserId,
        [FromBody] UpdateUserProfileRequest request)
    {
        _logger.LogInformation("Admin updating profile for user: {CognitoUserId}", cognitoUserId);

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
}
