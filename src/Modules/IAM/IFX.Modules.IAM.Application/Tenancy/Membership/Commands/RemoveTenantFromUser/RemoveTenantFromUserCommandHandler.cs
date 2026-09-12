using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tenancy.Membership.Commands.RemoveTenantFromUser;
public class RemoveTenantFromUserCommandHandler : IRequestHandler<RemoveTenantFromUserCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<RemoveTenantFromUserCommandHandler> _logger;
    public RemoveTenantFromUserCommandHandler(IUnitOfWork unitOfWork, ILogger<RemoveTenantFromUserCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(RemoveTenantFromUserCommand request, CancellationToken cancellationToken)
    {
        {
            var user = await _unitOfWork.Users.GetByIdWithTenantsAndDepartmentsAsync(request.UserId, cancellationToken);
            if (user == null)
                return Result<bool>.Failure("User not found");
            user.RemoveTenant(request.TenantId);
            // Clear primary tenant if it was the removed one
            if (user.PrimaryTenantId == request.TenantId)
                user.SetPrimaryTenant(Guid.Empty);
            _logger.LogInformation("Tenant {TenantId} removed from user {UserId}", request.TenantId, request.UserId);
            return Result<bool>.Success(true);
        }
    }
}
