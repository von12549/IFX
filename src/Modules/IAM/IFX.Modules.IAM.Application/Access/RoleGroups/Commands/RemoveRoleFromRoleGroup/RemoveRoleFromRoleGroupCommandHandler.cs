using IFX.Modules.IAM.Application.Ports.Authorization;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Access.RoleGroups.Authorization;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Access.RoleGroups.Commands.RemoveRoleFromRoleGroup;
public class RemoveRoleFromRoleGroupCommandHandler : IRequestHandler<RemoveRoleFromRoleGroupCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<RemoveRoleFromRoleGroupCommandHandler> _logger;
    public RemoveRoleFromRoleGroupCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<RemoveRoleFromRoleGroupCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(RemoveRoleFromRoleGroupCommand request, CancellationToken cancellationToken)
    {
        {
            var tenantId = TenantAccessGuard.RequireTenant(_currentUser);
            var group = await _unitOfWork.RoleGroups.GetByIdWithRolesAsync(request.RoleGroupId, tenantId, cancellationToken);
            if (group == null)
                return Result<bool>.Failure("Role group not found");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("rolegroup", "manage", new RoleGroupResourceAttributes(group.Id, group.TenantId, group.CreatedBy), ct: cancellationToken);
            group.RemoveRole(request.RoleId);
            _logger.LogInformation("Removed role {RoleId} from role group {RoleGroupId}", request.RoleId, request.RoleGroupId);
            return Result<bool>.Success(true);
        }
    }
}
