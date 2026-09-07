using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Application.Users.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Users.Commands.AssignRolesToUser;
public class AssignRolesToUserCommandHandler : IRequestHandler<AssignRolesToUserCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<AssignRolesToUserCommandHandler> _logger;
    public AssignRolesToUserCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<AssignRolesToUserCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(AssignRolesToUserCommand request, CancellationToken cancellationToken)
    {
        {
            var user = await _unitOfWork.Users.GetByIdWithRolesAndGroupsAsync(request.UserId, cancellationToken);
            if (user == null)
                return Result<bool>.Failure("User not found");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("user", "manage", new UserResourceAttributes(user.Id, _currentUser.TenantId), ct: cancellationToken);
            foreach (var roleId in request.RoleIds)
            {
                var role = await _unitOfWork.Roles.GetByIdAsync(roleId, cancellationToken);
                if (role == null)
                    return Result<bool>.Failure($"Role {roleId} not found");
                user.AddRole(role);
            }

            _logger.LogInformation("Assigned {Count} roles to user {UserId}", request.RoleIds.Count, request.UserId);
            return Result<bool>.Success(true);
        }
    }
}
