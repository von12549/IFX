using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Commands.DeletePermission;

public class DeletePermissionCommandHandler : IRequestHandler<DeletePermissionCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<DeletePermissionCommandHandler> _logger;

    public DeletePermissionCommandHandler(IUnitOfWork unitOfWork, ILogger<DeletePermissionCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(DeletePermissionCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var permission = await _unitOfWork.Permissions.GetByIdAsync(request.PermissionId, cancellationToken);
            if (permission == null)
                return Result<bool>.Failure("Permission not found");

            _unitOfWork.Permissions.Remove(permission);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Permission {PermissionId} deleted", request.PermissionId);
            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting permission {PermissionId}", request.PermissionId);
            return Result<bool>.Failure("An error occurred while deleting the permission");
        }
    }
}
