using AuthSamples.Modules.Cognito.API.Models;
using AuthSamples.Modules.Cognito.API.Models.Requests;
using AuthSamples.Modules.Cognito.API.Models.Responses;
using AuthSamples.Modules.Cognito.Application.Commands.ConfirmRegistration;
using AuthSamples.Modules.Cognito.Application.Commands.LoginUser;
using AuthSamples.Modules.Cognito.Application.Commands.LogoutUser;
using AuthSamples.Modules.Cognito.Application.Commands.RefreshToken;
using AuthSamples.Modules.Cognito.Application.Commands.RegisterUser;
using AuthSamples.Modules.Cognito.Application.Commands.RevokeToken;
using AuthSamples.Modules.Cognito.Application.Interfaces;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AuthSamples.Modules.Cognito.API.Controllers;

[ApiController]
[Route("api/v1/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ILogger<AuthController> _logger;
    private readonly IUnitOfWork _unitOfWork;

    public AuthController(IMediator mediator, ILogger<AuthController> logger, IUnitOfWork unitOfWork)
    {
        _mediator = mediator;
        _logger = logger;
        _unitOfWork = unitOfWork;
    }

    /// <summary>
    /// Register a new user account
    /// </summary>
    [HttpPost("register")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<ApiResponse<object>>> Register([FromBody] RegisterRequest request)
    {
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "Unknown";

        var command = new RegisterUserCommand(
            request.Email,
            request.Password,
            request.Username,
            request.FirstName,
            request.LastName,
            request.BirthDate.ToString("yyyy-MM-dd"),
            request.PhoneNumber,
            ipAddress);

        var result = await _mediator.Send(command);

        if (!result.IsSuccess)
        {
            return BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(new
        {
            Message = "Registration successful. Please check your email for the confirmation code.",
            RequiresConfirmation = result.Value!.RequiresConfirmation
        }));
    }

    /// <summary>
    /// Confirm user email with verification code
    /// </summary>
    [HttpPost("confirm")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<ApiResponse<object>>> ConfirmRegistration([FromBody] ConfirmRegistrationRequest request)
    {
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "Unknown";

        var command = new ConfirmRegistrationCommand(
            request.Email,
            request.ConfirmationCode,
            ipAddress);

        var result = await _mediator.Send(command);

        if (!result.IsSuccess)
        {
            return BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(new
        {
            Message = "Email confirmed successfully. You can now log in."
        }));
    }

    /// <summary>
    /// Authenticate user with email and password
    /// </summary>
    [HttpPost("login")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<ApiResponse<object>>> Login([FromBody] LoginRequest request)
    {
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "Unknown";
        var userAgent = HttpContext.Request.Headers.UserAgent.ToString();

        var command = new LoginUserCommand(
            request.Email,
            request.Password,
            ipAddress,
            userAgent);

        var result = await _mediator.Send(command);

        if (!result.IsSuccess)
        {
            return Unauthorized(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    /// <summary>
    /// Refresh access token using a valid refresh token
    /// </summary>
    [AllowAnonymous]
    [HttpPost("refresh")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status404NotFound)]
    public async Task<ActionResult<ApiResponse<object>>> RefreshToken([FromBody] RefreshTokenRequest request, CancellationToken cancellationToken)
    {
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "Unknown";

        // Query user by email to get Subject
        var user = await _unitOfWork.Users.GetByEmailAsync(request.Email, cancellationToken);
        if (user == null)
        {
            _logger.LogWarning("User not found for email {Email}", request.Email);
            return NotFound(ApiResponse<object>.FailureResponse("User not found"));
        }

        var command = new RefreshTokenCommand(
            request.RefreshToken,
            Username: user.Subject.Value,
            ipAddress);

        var result = await _mediator.Send(command, cancellationToken);

        if (!result.IsSuccess)
        {
            _logger.LogWarning("Token refresh failed for {Email}: {ErrorMessage}", request.Email, result.Error);
            return BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        _logger.LogInformation("Token refreshed successfully for {Email}", request.Email);
        return Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    /// <summary>
    /// Revoke a refresh token to invalidate it
    /// </summary>
    [AllowAnonymous]
    [HttpPost("revoke")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<ApiResponse<object>>> RevokeToken([FromBody] Models.RevokeTokenRequest request, CancellationToken cancellationToken)
    {
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "Unknown";

        var command = new Application.Commands.RevokeToken.RevokeTokenCommand(
            request.RefreshToken,
            Email: null, // Email is optional for revoke
            ipAddress);

        var result = await _mediator.Send(command, cancellationToken);

        if (!result.IsSuccess)
        {
            _logger.LogWarning("Token revocation failed: {ErrorMessage}", result.Error);
            return BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        _logger.LogInformation("Refresh token revoked successfully");
        return Ok(ApiResponse<object>.SuccessResponse(new { Message = "Refresh token revoked successfully" }));
    }

    /// <summary>
    /// Logout user and invalidate session
    /// </summary>
    [Authorize]
    [HttpPost("logout")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<ApiResponse<object>>> Logout()
    {
        var accessToken = HttpContext.Request.Headers.Authorization.ToString().Replace("Bearer ", "");
        var ipAddress = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "Unknown";

        // Extract user ID from claims
        var subject = User.FindFirst("sub")?.Value;
        if (string.IsNullOrEmpty(subject))
        {
            return Unauthorized(ApiResponse<object>.FailureResponse("Invalid token"));
        }

        var command = new LogoutUserCommand(
            subject,
            accessToken,
            ipAddress);

        var result = await _mediator.Send(command);

        if (!result.IsSuccess)
        {
            return BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(new
        {
            Message = "Logged out successfully"
        }));
    }
}
