using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Users.Commands.RemoveRoleGroupFromUser;

public class RemoveRoleGroupFromUserCommandHandler : IRequestHandler<RemoveRoleGroupFromUserCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<RemoveRoleGroupFromUserCommandHandler> _logger;

    public RemoveRoleGroupFromUserCommandHandler(IUnitOfWork unitOfWork, ILogger<RemoveRoleGroupFromUserCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(RemoveRoleGroupFromUserCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var user = await _unitOfWork.Users.GetByIdWithRolesAndGroupsAsync(request.UserId, cancellationToken);
            if (user == null)
                return Result<bool>.Failure("User not found");

            user.RemoveRoleGroup(request.RoleGroupId);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Removed role group {RoleGroupId} from user {UserId}", request.RoleGroupId, request.UserId);
            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing role group from user {UserId}", request.UserId);
            return Result<bool>.Failure("An error occurred while removing the role group");
        }
    }
}
