using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Commands.DeleteDepartment;

public class DeleteDepartmentCommandHandler : IRequestHandler<DeleteDepartmentCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<DeleteDepartmentCommandHandler> _logger;

    public DeleteDepartmentCommandHandler(IUnitOfWork unitOfWork, ILogger<DeleteDepartmentCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(DeleteDepartmentCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var department = await _unitOfWork.Departments.GetByIdAsync(request.DepartmentId, cancellationToken);
            if (department == null)
                return Result<bool>.Failure("Department not found");

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
