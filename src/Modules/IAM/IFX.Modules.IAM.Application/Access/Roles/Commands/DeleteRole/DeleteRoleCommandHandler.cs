using IFX.Modules.IAM.Application.Ports.Authorization;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Access.Roles.Authorization;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Access.Roles.Commands.DeleteRole;
public class DeleteRoleCommandHandler : IRequestHandler<DeleteRoleCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<DeleteRoleCommandHandler> _logger;
    public DeleteRoleCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<DeleteRoleCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(DeleteRoleCommand request, CancellationToken cancellationToken)
    {
        {
            var tenantId = TenantAccessGuard.RequireTenant(_currentUser);
            var role = await _unitOfWork.Roles.GetByIdAsync(request.RoleId, tenantId, cancellationToken);
            if (role == null)
                return Result<bool>.Failure("Role not found");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("role", "delete", new RoleResourceAttributes(role.Id, role.TenantId, role.CreatedBy), ct: cancellationToken);
            _unitOfWork.Roles.Remove(role);
            _logger.LogInformation("Role {RoleId} deleted", request.RoleId);
            return Result<bool>.Success(true);
        }
    }
}
