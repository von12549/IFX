using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tenancy.Membership.Commands.RemoveTenantFromUser;
public class RemoveTenantFromUserCommandHandler : IRequestHandler<RemoveTenantFromUserCommand, Result<bool>>
{
    private readonly IPermissionChecker _permission;
    private readonly ICurrentUser _currentUser;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<RemoveTenantFromUserCommandHandler> _logger;
    public RemoveTenantFromUserCommandHandler(IUnitOfWork unitOfWork, ILogger<RemoveTenantFromUserCommandHandler> logger, IPermissionChecker permission, ICurrentUser currentUser)
    {
        _permission = permission;
        _currentUser = currentUser;
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(RemoveTenantFromUserCommand request, CancellationToken cancellationToken)
    {
        {
            if (!await _permission.HasPermissionAsync("User:update", cancellationToken)) return Result<bool>.Failure("Membership management is not authorized.");
            if (_currentUser.TenantId is { } scopeTenant && scopeTenant != request.TenantId) return Result<bool>.Failure("Membership tenant does not match execution scope.");
            var user = await _unitOfWork.Users.GetByIdWithTenantsAndDepartmentsAsync(request.UserId, cancellationToken);
            if (user == null)
                return Result<bool>.Failure("User not found");
            user.RemoveTenant(request.TenantId);
            _logger.LogInformation("Tenant {TenantId} removed from user {UserId}", request.TenantId, request.UserId);
            return Result<bool>.Success(true);
        }
    }
}
