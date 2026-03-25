using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Authorization.Roles.Authorization;
using IFX.Modules.Auth.Application.Authorization.Roles.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Roles.Commands.AssignPermissionsToRole;

public class AssignPermissionsToRoleCommandHandler : IRequestHandler<AssignPermissionsToRoleCommand, Result<RoleDetailDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<AssignPermissionsToRoleCommandHandler> _logger;

    public AssignPermissionsToRoleCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, IResourceAuthorizationService authorizationService, ILogger<AssignPermissionsToRoleCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<RoleDetailDto>> Handle(AssignPermissionsToRoleCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var role = await _unitOfWork.Roles.GetByIdWithPermissionsAsync(request.RoleId, cancellationToken);
            if (role == null)
                return Result<RoleDetailDto>.Failure("Role not found");

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "role", "manage",
                new RoleResourceAttributes(role.Id, role.TenantId, role.CreatedBy),
                ct: cancellationToken);

            foreach (var permissionId in request.PermissionIds)
            {
                var permission = await _unitOfWork.Permissions.GetByIdAsync(permissionId, cancellationToken);
                if (permission == null)
                    return Result<RoleDetailDto>.Failure($"Permission {permissionId} not found");

                role.AddPermission(permission);
            }

            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Assigned {Count} permissions to role {RoleId}", request.PermissionIds.Count, request.RoleId);
            return Result<RoleDetailDto>.Success(_mapper.Map<RoleDetailDto>(role));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error assigning permissions to role {RoleId}", request.RoleId);
            return Result<RoleDetailDto>.Failure("An error occurred while assigning permissions");
        }
    }
}
