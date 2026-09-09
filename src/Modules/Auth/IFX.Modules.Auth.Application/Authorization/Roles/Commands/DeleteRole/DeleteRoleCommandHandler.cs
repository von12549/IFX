using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Authorization.Roles.Authorization;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Roles.Commands.DeleteRole;
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
