using AuthSamples.Modules.Auth.API.Models.Requests;
using AuthSamples.Modules.Auth.API.Models.Responses;
using AuthSamples.Modules.Auth.Application.Commands.AddRole;
using AuthSamples.Modules.Auth.Application.Commands.UpdateRole;
using AuthSamples.Modules.Auth.Application.Queries.GetAllRoles;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AuthSamples.Modules.Auth.API.Controllers;

[Authorize(Roles = "Admin")]
[ApiController]
[Route("api/v1/[controller]")]
public class RoleController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ILogger<RoleController> _logger;

    public RoleController(IMediator mediator, ILogger<RoleController> logger)
    {
        _mediator = mediator;
        _logger = logger;
    }

    /// <summary>
    /// Get all user roles (Admin only)
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<ApiResponse<object>>> GetAllRoles()
    {
        _logger.LogInformation("Admin accessing roles list");

        var query = new GetAllRolesQuery();
        var result = await _mediator.Send(query);

        if (!result.IsSuccess)
        {
            return BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    /// <summary>
    /// Update an existing role (Admin only)
    /// </summary>
    [HttpPut("{roleId}")]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<ApiResponse<object>>> UpdateRole(
        Guid roleId,
        [FromBody] UpdateRoleRequest request)
    {
        _logger.LogInformation("Admin updating role: {RoleId}", roleId);

        var command = new UpdateRoleCommand(roleId, request.RoleName, request.Description);
        var result = await _mediator.Send(command);

        if (!result.IsSuccess)
        {
            return BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }

    /// <summary>
    /// Add a new role (Admin only)
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ApiResponse<object>), StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<ApiResponse<object>>> AddRole(
        [FromBody] AddRoleRequest request)
    {
        _logger.LogInformation("Admin adding new role: {RoleName}", request.RoleName);

        var command = new AddRoleCommand(request.RoleName, request.Description);
        var result = await _mediator.Send(command);

        if (!result.IsSuccess)
        {
            return BadRequest(ApiResponse<object>.FailureResponse(result.Error!));
        }

        return Ok(ApiResponse<object>.SuccessResponse(result.Value!));
    }
}
