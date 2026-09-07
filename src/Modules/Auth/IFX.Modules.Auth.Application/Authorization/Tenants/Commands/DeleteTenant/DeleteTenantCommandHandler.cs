using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Tenants.Commands.DeleteTenant;
public class DeleteTenantCommandHandler : IRequestHandler<DeleteTenantCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ILogger<DeleteTenantCommandHandler> _logger;
    public DeleteTenantCommandHandler(IUnitOfWork unitOfWork, ILogger<DeleteTenantCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(DeleteTenantCommand request, CancellationToken cancellationToken)
    {
        {
            var tenant = await _unitOfWork.Tenants.GetByIdAsync(request.TenantId, cancellationToken);
            if (tenant == null)
                return Result<bool>.Failure("Tenant not found");
            _unitOfWork.Tenants.Remove(tenant);
            _logger.LogInformation("Tenant {TenantId} deleted", request.TenantId);
            return Result<bool>.Success(true);
        }
    }
}
