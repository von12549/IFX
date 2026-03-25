using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Authorization.Departments.Authorization;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Departments.Commands.DeleteDepartment;

public class DeleteDepartmentCommandHandler : IRequestHandler<DeleteDepartmentCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<DeleteDepartmentCommandHandler> _logger;

    public DeleteDepartmentCommandHandler(IUnitOfWork unitOfWork, IResourceAuthorizationService authorizationService, ILogger<DeleteDepartmentCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(DeleteDepartmentCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var department = await _unitOfWork.Departments.GetByIdAsync(request.DepartmentId, cancellationToken);
            if (department == null)
                return Result<bool>.Failure("Department not found");

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "department", "delete",
                new DepartmentResourceAttributes(department.Id, department.TenantId, department.CreatedBy),
                ct: cancellationToken);

            _unitOfWork.Departments.Remove(department);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Department {DepartmentId} deleted", request.DepartmentId);
            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error deleting department {DepartmentId}", request.DepartmentId);
            return Result<bool>.Failure("An error occurred while deleting the department");
        }
    }
}
