using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Application.Users.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Users.Commands.RemoveRoleFromUser;
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
