using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Access.GlobalRoles.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Access.GlobalRoles.Queries.GetUserGlobalRoles;

public class GetUserGlobalRolesQueryHandler : IRequestHandler<GetUserGlobalRolesQuery, Result<List<GlobalRoleDto>>>
{
    private readonly IPermissionChecker _permission;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<GetUserGlobalRolesQueryHandler> _logger;

    public GetUserGlobalRolesQueryHandler(IUnitOfWork unitOfWork, ILogger<GetUserGlobalRolesQueryHandler> logger, IPermissionChecker permission)
    {
        _permission = permission;
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<List<GlobalRoleDto>>> Handle(
        GetUserGlobalRolesQuery request, CancellationToken cancellationToken)
    {
        try
        {
            if (!await _permission.HasPermissionAsync("Platform.GlobalRole:manage", cancellationToken)) return Result<List<GlobalRoleDto>>.Failure("Platform authorization required.");
            var roles = await _unitOfWork.GlobalRoles.GetByUserIdAsync(request.UserId, cancellationToken);
            return Result<List<GlobalRoleDto>>.Success(
                roles.Select(r => new GlobalRoleDto(r.Id, r.Name, r.Description)).ToList());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving global roles for user {UserId}", request.UserId);
            return Result<List<GlobalRoleDto>>.Failure("An error occurred while retrieving user global roles.");
        }
    }
}
