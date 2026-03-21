using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Commands.RemovePermissionFromRole;

public class RemovePermissionFromRoleCommandHandler : IRequestHandler<RemovePermissionFromRoleCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<RemovePermissionFromRoleCommandHandler> _logger;

    public RemovePermissionFromRoleCommandHandler(IUnitOfWork unitOfWork, ILogger<RemovePermissionFromRoleCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(RemovePermissionFromRoleCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var role = await _unitOfWork.Roles.GetByIdWithPermissionsAsync(request.RoleId, cancellationToken);
            if (role == null)
                return Result<bool>.Failure("Role not found");

            role.RemovePermission(request.PermissionId);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Removed permission {PermissionId} from role {RoleId}", request.PermissionId, request.RoleId);
            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing permission from role {RoleId}", request.RoleId);
            return Result<bool>.Failure("An error occurred while removing the permission");
        }
    }
}
