using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Users.Commands.AssignRolesToUser;

public class AssignRolesToUserCommandHandler : IRequestHandler<AssignRolesToUserCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<AssignRolesToUserCommandHandler> _logger;

    public AssignRolesToUserCommandHandler(IUnitOfWork unitOfWork, ILogger<AssignRolesToUserCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(AssignRolesToUserCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var user = await _unitOfWork.Users.GetByIdWithRolesAndGroupsAsync(request.UserId, cancellationToken);
            if (user == null)
                return Result<bool>.Failure("User not found");

            foreach (var roleId in request.RoleIds)
            {
                var role = await _unitOfWork.Roles.GetByIdAsync(roleId, cancellationToken);
                if (role == null)
                    return Result<bool>.Failure($"Role {roleId} not found");

                user.AddRole(role);
            }

            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Assigned {Count} roles to user {UserId}", request.RoleIds.Count, request.UserId);
            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error assigning roles to user {UserId}", request.UserId);
            return Result<bool>.Failure("An error occurred while assigning roles");
        }
    }
}
