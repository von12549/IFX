using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Users.Commands.RemoveRoleFromUser;

public class RemoveRoleFromUserCommandHandler : IRequestHandler<RemoveRoleFromUserCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<RemoveRoleFromUserCommandHandler> _logger;

    public RemoveRoleFromUserCommandHandler(IUnitOfWork unitOfWork, ILogger<RemoveRoleFromUserCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(RemoveRoleFromUserCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var user = await _unitOfWork.Users.GetByIdWithRolesAndGroupsAsync(request.UserId, cancellationToken);
            if (user == null)
                return Result<bool>.Failure("User not found");

            user.RemoveRole(request.RoleId);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Removed role {RoleId} from user {UserId}", request.RoleId, request.UserId);
            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing role from user {UserId}", request.UserId);
            return Result<bool>.Failure("An error occurred while removing the role");
        }
    }
}
