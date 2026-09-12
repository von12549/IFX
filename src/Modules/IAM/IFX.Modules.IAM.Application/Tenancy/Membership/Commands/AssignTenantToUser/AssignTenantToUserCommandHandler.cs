using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tenancy.Membership.Commands.AssignTenantToUser;
public class AssignTenantToUserCommandHandler : IRequestHandler<AssignTenantToUserCommand, Result<bool>>
{
    private readonly IPermissionChecker _permission;
    private readonly ICurrentUser _currentUser;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<AssignTenantToUserCommandHandler> _logger;
    public AssignTenantToUserCommandHandler(IUnitOfWork unitOfWork, ILogger<AssignTenantToUserCommandHandler> logger, IPermissionChecker permission, ICurrentUser currentUser)
    {
        _permission = permission;
        _currentUser = currentUser;
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(AssignTenantToUserCommand request, CancellationToken cancellationToken)
    {
        {
            if (!await _permission.HasPermissionAsync("User:update", cancellationToken)) return Result<bool>.Failure("Membership management is not authorized.");
            if (_currentUser.TenantId is { } scopeTenant && scopeTenant != request.TenantId) return Result<bool>.Failure("Membership tenant does not match execution scope.");
            var user = await _unitOfWork.Users.GetByIdWithTenantsAndDepartmentsAsync(request.UserId, cancellationToken);
            if (user == null)
                return Result<bool>.Failure("User not found");
            var tenant = await _unitOfWork.Tenants.GetByIdAsync(request.TenantId, cancellationToken);
            if (tenant == null || !tenant.IsActive)
                return Result<bool>.Failure("Tenant not found");
            user.AddTenant(tenant);
            if (request.SetAsPrimary || user.PrimaryTenantId == null)
                user.SetPrimaryTenant(request.TenantId);
            _logger.LogInformation("Tenant {TenantId} assigned to user {UserId}", request.TenantId, request.UserId);
            return Result<bool>.Success(true);
        }
    }
}
