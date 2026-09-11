using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Auth.Application.Authorization.RoleGroups.Authorization;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.RoleGroups.Commands.DeleteRoleGroup;
public class DeleteRoleGroupCommandHandler : IRequestHandler<DeleteRoleGroupCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<DeleteRoleGroupCommandHandler> _logger;
    public DeleteRoleGroupCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<DeleteRoleGroupCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(DeleteRoleGroupCommand request, CancellationToken cancellationToken)
    {
        {
            var tenantId = TenantAccessGuard.RequireTenant(_currentUser);
            var group = await _unitOfWork.RoleGroups.GetByIdAsync(request.RoleGroupId, tenantId, cancellationToken);
            if (group == null)
                return Result<bool>.Failure("Role group not found");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("rolegroup", "delete", new RoleGroupResourceAttributes(group.Id, group.TenantId, group.CreatedBy), ct: cancellationToken);
            _unitOfWork.RoleGroups.Remove(group);
            _logger.LogInformation("Role group {RoleGroupId} deleted", request.RoleGroupId);
            return Result<bool>.Success(true);
        }
    }
}
