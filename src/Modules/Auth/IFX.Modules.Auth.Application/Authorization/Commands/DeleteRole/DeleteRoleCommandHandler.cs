using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Commands.DeleteRole;

public class DeleteRoleCommandHandler : IRequestHandler<DeleteRoleCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<DeleteRoleCommandHandler> _logger;

    public DeleteRoleCommandHandler(IUnitOfWork unitOfWork, ILogger<DeleteRoleCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(DeleteRoleCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var role = await _unitOfWork.Roles.GetByIdAsync(request.RoleId, cancellationToken);
            if (role == null)
                return Result<bool>.Failure("Role not found");

            _unitOfWork.Roles.Remove(role);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Role {RoleId} deleted", request.RoleId);
            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting role {RoleId}", request.RoleId);
            return Result<bool>.Failure("An error occurred while deleting the role");
        }
    }
}
