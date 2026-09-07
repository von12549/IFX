using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Application.Users.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Users.Commands.RemoveRoleGroupFromUser;
public class RemoveRoleGroupFromUserCommandHandler : IRequestHandler<RemoveRoleGroupFromUserCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<RemoveRoleGroupFromUserCommandHandler> _logger;
    public RemoveRoleGroupFromUserCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<RemoveRoleGroupFromUserCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(RemoveRoleGroupFromUserCommand request, CancellationToken cancellationToken)
    {
        {
            var user = await _unitOfWork.Users.GetByIdWithRolesAndGroupsAsync(request.UserId, cancellationToken);
            if (user == null)
                return Result<bool>.Failure("User not found");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("user", "manage", new UserResourceAttributes(user.Id, _currentUser.TenantId), ct: cancellationToken);
            user.RemoveRoleGroup(request.RoleGroupId);
            _logger.LogInformation("Removed role group {RoleGroupId} from user {UserId}", request.RoleGroupId, request.UserId);
            return Result<bool>.Success(true);
        }
    }
}
