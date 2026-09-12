using IFX.Modules.IAM.Application.Ports.Authorization;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Access.Roles.Authorization;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Access.Roles.Commands.RemovePermissionFromRole;
public class RemovePermissionFromRoleCommandHandler : IRequestHandler<RemovePermissionFromRoleCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<RemovePermissionFromRoleCommandHandler> _logger;
    public RemovePermissionFromRoleCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<RemovePermissionFromRoleCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(RemovePermissionFromRoleCommand request, CancellationToken cancellationToken)
    {
        {
            var tenantId = TenantAccessGuard.RequireTenant(_currentUser);
            var role = await _unitOfWork.Roles.GetByIdWithPermissionsAsync(request.RoleId, tenantId, cancellationToken);
            if (role == null)
                return Result<bool>.Failure("Role not found");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("role", "manage", new RoleResourceAttributes(role.Id, role.TenantId, role.CreatedBy), ct: cancellationToken);
            role.RemovePermission(request.PermissionId);
            _logger.LogInformation("Removed permission {PermissionId} from role {RoleId}", request.PermissionId, request.RoleId);
            return Result<bool>.Success(true);
        }
    }
}
