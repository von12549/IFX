using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Commands.RemoveRoleFromRoleGroup;

public class RemoveRoleFromRoleGroupCommandHandler : IRequestHandler<RemoveRoleFromRoleGroupCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<RemoveRoleFromRoleGroupCommandHandler> _logger;

    public RemoveRoleFromRoleGroupCommandHandler(IUnitOfWork unitOfWork, ILogger<RemoveRoleFromRoleGroupCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(RemoveRoleFromRoleGroupCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var group = await _unitOfWork.RoleGroups.GetByIdWithRolesAsync(request.RoleGroupId, cancellationToken);
            if (group == null)
                return Result<bool>.Failure("Role group not found");

            group.RemoveRole(request.RoleId);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Removed role {RoleId} from role group {RoleGroupId}", request.RoleId, request.RoleGroupId);
            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing role from role group {RoleGroupId}", request.RoleGroupId);
            return Result<bool>.Failure("An error occurred while removing the role");
        }
    }
}
