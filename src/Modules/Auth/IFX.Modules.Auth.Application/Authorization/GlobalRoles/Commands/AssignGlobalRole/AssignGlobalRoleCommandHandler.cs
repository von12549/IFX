using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.GlobalRoles.Commands.AssignGlobalRole;

public class AssignGlobalRoleCommandHandler : IRequestHandler<AssignGlobalRoleCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<AssignGlobalRoleCommandHandler> _logger;

    public AssignGlobalRoleCommandHandler(
        IUnitOfWork unitOfWork,
        ICurrentUser currentUser,
        ILogger<AssignGlobalRoleCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(AssignGlobalRoleCommand request, CancellationToken cancellationToken)
    {
        try
        {
            // Only PlatformAdmins can assign any GlobalRole
            if (!_currentUser.IsGlobalAdmin)
                return Result<bool>.Failure("Only platform admins can assign global roles.");

            var globalRole = await _unitOfWork.GlobalRoles.GetByIdAsync(request.GlobalRoleId, cancellationToken);
            if (globalRole is null)
                return Result<bool>.Failure("Global role not found.");

            var user = await _unitOfWork.Users.GetByIdAsync(request.UserId, cancellationToken);
            if (user is null)
                return Result<bool>.Failure("User not found.");

            var existing = await _unitOfWork.GlobalRoles.GetUserGlobalRoleAsync(
                request.UserId, request.GlobalRoleId, cancellationToken);
            if (existing is not null)
                return Result<bool>.Failure("User already has this global role.");

            var assignment = UserGlobalRole.Create(request.UserId, request.GlobalRoleId);
            await _unitOfWork.GlobalRoles.AddUserGlobalRoleAsync(assignment, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation(
                "GlobalRole '{RoleName}' assigned to user {UserId} by {AssignedBy}",
                globalRole.Name, request.UserId, _currentUser.UserId);

            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex,
                "Error assigning global role {GlobalRoleId} to user {UserId}",
                request.GlobalRoleId, request.UserId);
            return Result<bool>.Failure("An error occurred while assigning the global role.");
        }
    }
}
