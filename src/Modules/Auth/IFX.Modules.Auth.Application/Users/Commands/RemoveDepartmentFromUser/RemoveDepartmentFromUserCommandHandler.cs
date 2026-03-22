using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Users.Commands.RemoveDepartmentFromUser;

public class RemoveDepartmentFromUserCommandHandler : IRequestHandler<RemoveDepartmentFromUserCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<RemoveDepartmentFromUserCommandHandler> _logger;

    public RemoveDepartmentFromUserCommandHandler(IUnitOfWork unitOfWork, ILogger<RemoveDepartmentFromUserCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(RemoveDepartmentFromUserCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var user = await _unitOfWork.Users.GetByIdWithTenantsAndDepartmentsAsync(request.UserId, cancellationToken);
            if (user == null)
                return Result<bool>.Failure("User not found");

            user.RemoveDepartment(request.DepartmentId);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Department {DepartmentId} removed from user {UserId}", request.DepartmentId, request.UserId);
            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error removing department {DepartmentId} from user {UserId}", request.DepartmentId, request.UserId);
            return Result<bool>.Failure("An error occurred while removing the department");
        }
    }
}
