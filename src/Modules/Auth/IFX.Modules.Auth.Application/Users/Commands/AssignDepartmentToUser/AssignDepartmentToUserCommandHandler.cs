using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Users.Commands.AssignDepartmentToUser;

public class AssignDepartmentToUserCommandHandler : IRequestHandler<AssignDepartmentToUserCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<AssignDepartmentToUserCommandHandler> _logger;

    public AssignDepartmentToUserCommandHandler(IUnitOfWork unitOfWork, ILogger<AssignDepartmentToUserCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(AssignDepartmentToUserCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var user = await _unitOfWork.Users.GetByIdWithTenantsAndDepartmentsAsync(request.UserId, cancellationToken);
            if (user == null)
                return Result<bool>.Failure("User not found");

            var department = await _unitOfWork.Departments.GetByIdAsync(request.DepartmentId, cancellationToken);
            if (department == null)
                return Result<bool>.Failure("Department not found");

            // Enforce: user must belong to the department's tenant
            if (!user.Tenants.Any(t => t.Id == department.TenantId))
                return Result<bool>.Failure("User is not a member of the tenant that owns this department");

            user.AddDepartment(department);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Department {DepartmentId} assigned to user {UserId}", request.DepartmentId, request.UserId);
            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error assigning department {DepartmentId} to user {UserId}", request.DepartmentId, request.UserId);
            return Result<bool>.Failure("An error occurred while assigning the department");
        }
    }
}
