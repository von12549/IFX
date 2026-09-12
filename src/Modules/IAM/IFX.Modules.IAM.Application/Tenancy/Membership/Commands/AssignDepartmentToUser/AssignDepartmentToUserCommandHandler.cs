using IFX.Modules.IAM.Application.Common;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tenancy.Membership.Commands.AssignDepartmentToUser;
public class AssignDepartmentToUserCommandHandler : IRequestHandler<AssignDepartmentToUserCommand, Result<bool>>
{
    private readonly IPermissionChecker _permission;
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<AssignDepartmentToUserCommandHandler> _logger;
    public AssignDepartmentToUserCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, ILogger<AssignDepartmentToUserCommandHandler> logger, IPermissionChecker permission)
    {
        _permission = permission;
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(AssignDepartmentToUserCommand request, CancellationToken cancellationToken)
    {
        {
            if (!await _permission.HasPermissionAsync("User:update", cancellationToken)) return Result<bool>.Failure("Membership management is not authorized.");
            var user = await _unitOfWork.Users.GetByIdWithTenantsAndDepartmentsAsync(request.UserId, cancellationToken);
            if (user == null)
                return Result<bool>.Failure("User not found");
            var tenantId = TenantAccessGuard.RequireTenant(_currentUser);
            var department = await _unitOfWork.Departments.GetByIdAsync(request.DepartmentId, tenantId, cancellationToken);
            if (department == null)
                return Result<bool>.Failure("Department not found");
            // Enforce: user must belong to the department's tenant
            if (!user.Tenants.Any(t => t.Id == department.TenantId))
                return Result<bool>.Failure("User is not a member of the tenant that owns this department");
            user.AddDepartment(department);
            _logger.LogInformation("Department {DepartmentId} assigned to user {UserId}", request.DepartmentId, request.UserId);
            return Result<bool>.Success(true);
        }
    }
}
