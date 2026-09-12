using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tenancy.Membership.Commands.RemoveDepartmentFromUser;
public class RemoveDepartmentFromUserCommandHandler : IRequestHandler<RemoveDepartmentFromUserCommand, Result<bool>>
{
    private readonly IPermissionChecker _permission;
    private readonly ICurrentUser _currentUser;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<RemoveDepartmentFromUserCommandHandler> _logger;
    public RemoveDepartmentFromUserCommandHandler(IUnitOfWork unitOfWork, ILogger<RemoveDepartmentFromUserCommandHandler> logger, IPermissionChecker permission, ICurrentUser currentUser)
    {
        _permission = permission;
        _currentUser = currentUser;
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(RemoveDepartmentFromUserCommand request, CancellationToken cancellationToken)
    {
        {
            if (!await _permission.HasPermissionAsync("User:update", cancellationToken)) return Result<bool>.Failure("Membership management is not authorized.");
            var user = await _unitOfWork.Users.GetByIdWithTenantsAndDepartmentsAsync(request.UserId, cancellationToken);
            if (user == null)
                return Result<bool>.Failure("User not found");
            var tenantId = TenantAccessGuard.RequireTenant(_currentUser);
            if (!user.Departments.Any(d => d.Id == request.DepartmentId && d.TenantId == tenantId))
                return Result<bool>.Failure("Department assignment not found in the current tenant.");
            user.RemoveDepartment(request.DepartmentId);
            _logger.LogInformation("Department {DepartmentId} removed from user {UserId}", request.DepartmentId, request.UserId);
            return Result<bool>.Success(true);
        }
    }
}
