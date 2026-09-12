using IFX.Modules.IAM.Application.Ports.Authorization;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Access.Roles.Authorization;
using IFX.Modules.IAM.Application.Access.Roles.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Access.Roles.Commands.AssignPermissionsToRole;
public class AssignPermissionsToRoleCommandHandler : IRequestHandler<AssignPermissionsToRoleCommand, Result<RoleDetailDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<AssignPermissionsToRoleCommandHandler> _logger;
    public AssignPermissionsToRoleCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<AssignPermissionsToRoleCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<RoleDetailDto>> Handle(AssignPermissionsToRoleCommand request, CancellationToken cancellationToken)
    {
        {
            var tenantId = TenantAccessGuard.RequireTenant(_currentUser);
            var role = await _unitOfWork.Roles.GetByIdWithPermissionsAsync(request.RoleId, tenantId, cancellationToken);
            if (role == null)
                return Result<RoleDetailDto>.Failure("Role not found");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("role", "manage", new RoleResourceAttributes(role.Id, role.TenantId, role.CreatedBy), ct: cancellationToken);
            foreach (var permissionId in request.PermissionIds)
            {
                var permission = await _unitOfWork.Permissions.GetByIdAsync(permissionId, cancellationToken);
                if (permission == null)
                    return Result<RoleDetailDto>.Failure($"Permission {permissionId} not found");
                role.AddPermission(permission);
            }

            _logger.LogInformation("Assigned {Count} permissions to role {RoleId}", request.PermissionIds.Count, request.RoleId);
            return Result<RoleDetailDto>.Success(_mapper.Map<RoleDetailDto>(role));
        }
    }
}
