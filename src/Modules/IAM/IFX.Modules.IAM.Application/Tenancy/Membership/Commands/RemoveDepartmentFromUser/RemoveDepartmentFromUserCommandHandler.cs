using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tenancy.Membership.Commands.RemoveDepartmentFromUser;
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
        {
            var user = await _unitOfWork.Users.GetByIdWithTenantsAndDepartmentsAsync(request.UserId, cancellationToken);
            if (user == null)
                return Result<bool>.Failure("User not found");
            user.RemoveDepartment(request.DepartmentId);
            _logger.LogInformation("Department {DepartmentId} removed from user {UserId}", request.DepartmentId, request.UserId);
            return Result<bool>.Success(true);
        }
    }
}
