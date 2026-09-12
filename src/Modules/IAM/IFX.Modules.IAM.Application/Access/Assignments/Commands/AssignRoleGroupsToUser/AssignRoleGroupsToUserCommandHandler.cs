using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Application.Users.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Access.Assignments.Commands.AssignRoleGroupsToUser;
public class AssignRoleGroupsToUserCommandHandler : IRequestHandler<AssignRoleGroupsToUserCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<AssignRoleGroupsToUserCommandHandler> _logger;
    public AssignRoleGroupsToUserCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<AssignRoleGroupsToUserCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(AssignRoleGroupsToUserCommand request, CancellationToken cancellationToken)
    {
        {
            var tenantId = TenantAccessGuard.RequireTenant(_currentUser);
            var user = await _unitOfWork.Users.GetByIdWithRolesAndGroupsAsync(request.UserId, cancellationToken);
            if (user == null)
                return Result<bool>.Failure("User not found");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("user", "manage", new UserResourceAttributes(user.Id, _currentUser.TenantId), ct: cancellationToken);
            foreach (var groupId in request.RoleGroupIds)
            {
                var group = await _unitOfWork.RoleGroups.GetByIdAsync(groupId, tenantId, cancellationToken);
                if (group == null)
                    return Result<bool>.Failure($"Role group {groupId} not found");
                user.AddRoleGroup(group);
            }

            _logger.LogInformation("Assigned {Count} role groups to user {UserId}", request.RoleGroupIds.Count, request.UserId);
            return Result<bool>.Success(true);
        }
    }
}
