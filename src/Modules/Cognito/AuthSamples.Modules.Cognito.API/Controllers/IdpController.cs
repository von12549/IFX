using AuthSamples.Modules.Cognito.API.Models.Requests;
using AuthSamples.Modules.Cognito.API.Models.Responses;
using AuthSamples.Modules.Cognito.Application.Commands.CreateIdp;
using AuthSamples.Modules.Cognito.Application.Commands.UpdateIdp;
using AuthSamples.Modules.Cognito.Application.Queries.GetAllIdps;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AuthSamples.Modules.Cognito.API.Controllers;

[Authorize(Roles = "Admin")]
[ApiController]
[Route("api/v1/[controller]")]
public class IdpController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ILogger<IdpController> _logger;

    public IdpController(IMediator mediator, ILogger<IdpController> logger)
    {
        _mediator = mediator;
        _logger = logger;
    }

    /// <summary>
    /// Get all Identity Providers (Admin only)
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<ApiResponse<object>>> GetAllIdps()
    {
        _logger.LogInformation("Admin accessing Identity Providers list");

        var query = new GetAllIdpsQuery();
        var result = await _mediator.Send(query);

        if (!result.IsSuccess)
        {
            return BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    /// <summary>
    /// Create a new Identity Provider (Admin only)
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<ApiResponse<object>>> CreateIdp(
        [FromBody] CreateIdpRequest request)
    {
        _logger.LogInformation("Admin creating new Identity Provider: {Name}", request.Name);

        var command = new CreateIdpCommand(
            request.Name,
            request.Issuer,
            request.Authority,
            request.Description,
            request.LoginUrl,
            request.Enabled,
            request.AutoProvisionEnabled,
            request.ExpectedAudiences,
            request.AllowedAlgs,
            request.RequiredScopes,
            request.ClaimMapping,
            request.ClockSkewSeconds);

        var result = await _mediator.Send(command);

        if (!result.IsSuccess)
        {
            return BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    /// <summary>
    /// Update an existing Identity Provider (Admin only)
    /// </summary>
    [HttpPut("{idpId}")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<ApiResponse<object>>> UpdateIdp(
        Guid idpId,
        [FromBody] UpdateIdpRequest request)
    {
        _logger.LogInformation("Admin updating Identity Provider: {IdpId}", idpId);

        var command = new UpdateIdpCommand(
            idpId,
            request.Name,
            request.Issuer,
            request.Authority,
            request.Description,
            request.LoginUrl,
            request.Enabled,
            request.AutoProvisionEnabled,
            request.ExpectedAudiences,
            request.AllowedAlgs,
            request.RequiredScopes,
            request.ClaimMapping,
            request.ClockSkewSeconds);

        var result = await _mediator.Send(command);

        if (!result.IsSuccess)
        {
            return BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
