using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Access.GlobalRoles.Commands.AssignGlobalRole;
public class AssignGlobalRoleCommandHandler : IRequestHandler<AssignGlobalRoleCommand, Result<bool>>
{
    private readonly IPermissionChecker _permission;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<AssignGlobalRoleCommandHandler> _logger;
    public AssignGlobalRoleCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, ILogger<AssignGlobalRoleCommandHandler> logger, IPermissionChecker permission)
    {
        _permission = permission;
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(AssignGlobalRoleCommand request, CancellationToken cancellationToken)
    {
        {
            if (!await _permission.HasPermissionAsync("Platform.GlobalRole:manage", cancellationToken)) return Result<bool>.Failure("Platform authorization required.");
            // Only PlatformAdmins can assign any GlobalRole
            if (!_currentUser.IsGlobalAdmin)
                return Result<bool>.Failure("Only platform admins can assign global roles.");
            var globalRole = await _unitOfWork.GlobalRoles.GetByIdAsync(request.GlobalRoleId, cancellationToken);
            if (globalRole is null)
                return Result<bool>.Failure("Global role not found.");
            var user = await _unitOfWork.Users.GetByIdAsync(request.UserId, cancellationToken);
            if (user is null)
                return Result<bool>.Failure("User not found.");
            var existing = await _unitOfWork.GlobalRoles.GetUserGlobalRoleAsync(request.UserId, request.GlobalRoleId, cancellationToken);
            if (existing is not null)
                return Result<bool>.Failure("User already has this global role.");
            var assignment = UserGlobalRole.Create(request.UserId, request.GlobalRoleId);
            await _unitOfWork.GlobalRoles.AddUserGlobalRoleAsync(assignment, cancellationToken);
            _logger.LogInformation("GlobalRole '{RoleName}' assigned to user {UserId} by {AssignedBy}", globalRole.Name, request.UserId, _currentUser.UserId);
            return Result<bool>.Success(true);
        }
    }
}
