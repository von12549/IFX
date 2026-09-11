using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Auth.Application.Authorization.RoleGroups.Authorization;
using IFX.Modules.Auth.Application.Authorization.RoleGroups.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.RoleGroups.Commands.AssignRolesToRoleGroup;
public class AssignRolesToRoleGroupCommandHandler : IRequestHandler<AssignRolesToRoleGroupCommand, Result<RoleGroupDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<AssignRolesToRoleGroupCommandHandler> _logger;
    public AssignRolesToRoleGroupCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<AssignRolesToRoleGroupCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<RoleGroupDto>> Handle(AssignRolesToRoleGroupCommand request, CancellationToken cancellationToken)
    {
        {
            var tenantId = TenantAccessGuard.RequireTenant(_currentUser);
            var group = await _unitOfWork.RoleGroups.GetByIdWithRolesAsync(request.RoleGroupId, tenantId, cancellationToken);
            if (group == null)
                return Result<RoleGroupDto>.Failure("Role group not found");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("rolegroup", "manage", new RoleGroupResourceAttributes(group.Id, group.TenantId, group.CreatedBy), ct: cancellationToken);
            foreach (var roleId in request.RoleIds)
            {
                var role = await _unitOfWork.Roles.GetByIdAsync(roleId, tenantId, cancellationToken);
                if (role == null)
                    return Result<RoleGroupDto>.Failure($"Role {roleId} not found");
                group.AddRole(role);
            }

            _logger.LogInformation("Assigned {Count} roles to role group {RoleGroupId}", request.RoleIds.Count, request.RoleGroupId);
            return Result<RoleGroupDto>.Success(_mapper.Map<RoleGroupDto>(group));
        }
    }
}
