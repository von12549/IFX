using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Commands.DeleteRoleGroup;

public class DeleteRoleGroupCommandHandler : IRequestHandler<DeleteRoleGroupCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<DeleteRoleGroupCommandHandler> _logger;

    public DeleteRoleGroupCommandHandler(IUnitOfWork unitOfWork, ILogger<DeleteRoleGroupCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(DeleteRoleGroupCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var group = await _unitOfWork.RoleGroups.GetByIdAsync(request.RoleGroupId, cancellationToken);
            if (group == null)
                return Result<bool>.Failure("Role group not found");

            _unitOfWork.RoleGroups.Remove(group);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Role group {RoleGroupId} deleted", request.RoleGroupId);
            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting role group {RoleGroupId}", request.RoleGroupId);
            return Result<bool>.Failure("An error occurred while deleting the role group");
        }
    }
}
