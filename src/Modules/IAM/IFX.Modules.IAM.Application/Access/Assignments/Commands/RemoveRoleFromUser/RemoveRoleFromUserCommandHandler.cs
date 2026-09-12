using IFX.Modules.IAM.Application.Ports.Authorization;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Application.Users.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Access.Assignments.Commands.RemoveRoleFromUser;
public class RemoveRoleFromUserCommandHandler : IRequestHandler<RemoveRoleFromUserCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<RemoveRoleFromUserCommandHandler> _logger;
    public RemoveRoleFromUserCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<RemoveRoleFromUserCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(RemoveRoleFromUserCommand request, CancellationToken cancellationToken)
    {
        {
            var user = await _unitOfWork.Users.GetByIdWithRolesAndGroupsAsync(request.UserId, cancellationToken);
            if (user == null)
                return Result<bool>.Failure("User not found");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("user", "manage", new UserResourceAttributes(user.Id, _currentUser.TenantId), ct: cancellationToken);
            user.RemoveRole(request.RoleId);
            _logger.LogInformation("Removed role {RoleId} from user {UserId}", request.RoleId, request.UserId);
            return Result<bool>.Success(true);
        }
    }
}
