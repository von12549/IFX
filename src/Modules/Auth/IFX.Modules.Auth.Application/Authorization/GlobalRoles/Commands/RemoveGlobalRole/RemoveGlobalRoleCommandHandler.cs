using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.GlobalRoles.Commands.RemoveGlobalRole;

public class RemoveGlobalRoleCommandHandler : IRequestHandler<RemoveGlobalRoleCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<RemoveGlobalRoleCommandHandler> _logger;

    public RemoveGlobalRoleCommandHandler(
        IUnitOfWork unitOfWork,
        ICurrentUser currentUser,
        ILogger<RemoveGlobalRoleCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(RemoveGlobalRoleCommand request, CancellationToken cancellationToken)
    {
        try
        {
            // Only PlatformAdmins can remove global roles
            if (!_currentUser.IsGlobalAdmin)
                return Result<bool>.Failure("Only platform admins can remove global roles.");

            var assignment = await _unitOfWork.GlobalRoles.GetUserGlobalRoleAsync(
                request.UserId, request.GlobalRoleId, cancellationToken);
            if (assignment is null)
                return Result<bool>.Failure("User does not have this global role.");

            var globalRole = await _unitOfWork.GlobalRoles.GetByIdAsync(request.GlobalRoleId, cancellationToken);

            // Guard: cannot remove PlatformAdmin if it would leave zero PlatformAdmins
            if (globalRole?.Name == GlobalRoleNames.PlatformAdmin)
            {
                var adminCount = await _unitOfWork.GlobalRoles.CountPlatformAdminsAsync(cancellationToken);
                if (adminCount <= 1)
                    return Result<bool>.Failure(
                        "Cannot remove the last PlatformAdmin. Assign another PlatformAdmin first.");
            }

            _unitOfWork.GlobalRoles.RemoveUserGlobalRole(assignment);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "GlobalRole '{RoleName}' removed from user {UserId} by {RemovedBy}",
                globalRole?.Name ?? request.GlobalRoleId.ToString(), request.UserId, _currentUser.UserId);

            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Error removing global role {GlobalRoleId} from user {UserId}",
                request.GlobalRoleId, request.UserId);
            return Result<bool>.Failure("An error occurred while removing the global role.");
        }
    }
}
