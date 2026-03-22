using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Users.Commands.AssignTenantToUser;

public class AssignTenantToUserCommandHandler : IRequestHandler<AssignTenantToUserCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<AssignTenantToUserCommandHandler> _logger;

    public AssignTenantToUserCommandHandler(IUnitOfWork unitOfWork, ILogger<AssignTenantToUserCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(AssignTenantToUserCommand request, CancellationToken cancellationToken)
    {
        try
        {
            var user = await _unitOfWork.Users.GetByIdWithTenantsAndDepartmentsAsync(request.UserId, cancellationToken);
            if (user == null)
                return Result<bool>.Failure("User not found");

            var tenant = await _unitOfWork.Tenants.GetByIdAsync(request.TenantId, cancellationToken);
            if (tenant == null)
                return Result<bool>.Failure("Tenant not found");

            user.AddTenant(tenant);

            if (request.SetAsPrimary || user.PrimaryTenantId == null)
                user.SetPrimaryTenant(request.TenantId);

            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Tenant {TenantId} assigned to user {UserId}", request.TenantId, request.UserId);
            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error assigning tenant {TenantId} to user {UserId}", request.TenantId, request.UserId);
            return Result<bool>.Failure("An error occurred while assigning the tenant");
        }
    }
}
