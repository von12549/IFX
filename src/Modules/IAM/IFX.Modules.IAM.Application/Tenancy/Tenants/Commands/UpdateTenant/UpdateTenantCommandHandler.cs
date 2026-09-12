using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Tenancy.Tenants.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tenancy.Tenants.Commands.UpdateTenant;
public class UpdateTenantCommandHandler : IRequestHandler<UpdateTenantCommand, Result<TenantDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IPermissionChecker _permission;
    private readonly ICurrentUser _currentUser;
    private readonly IMapper _mapper;
    private readonly ILogger<UpdateTenantCommandHandler> _logger;
    public UpdateTenantCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ILogger<UpdateTenantCommandHandler> logger, IPermissionChecker permission, ICurrentUser currentUser)
    {
        _unitOfWork = unitOfWork;
        _permission = permission;
        _currentUser = currentUser;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<TenantDto>> Handle(UpdateTenantCommand request, CancellationToken cancellationToken)
    {
        {
            if (!await _permission.HasPermissionAsync("Tenant:update", cancellationToken) ||
                (_currentUser.TenantId is { } tenantId && tenantId != request.TenantId)) return Result<TenantDto>.Failure("Tenant management is not authorized.");
            var tenant = await _unitOfWork.Tenants.GetByIdAsync(request.TenantId, cancellationToken);
            if (tenant == null)
                return Result<TenantDto>.Failure("Tenant not found");
            if (tenant.Name != request.Name && await _unitOfWork.Tenants.NameExistsAsync(request.Name, request.TenantId, cancellationToken))
                return Result<TenantDto>.Failure($"Tenant '{request.Name}' already exists");
            tenant.Update(request.Name, request.Description);
            if (request.IsActive is true) tenant.Activate();
            if (request.IsActive is false) tenant.Deactivate();
            _logger.LogInformation("Tenant {TenantId} updated: {Name}", request.TenantId, request.Name);
            return Result<TenantDto>.Success(_mapper.Map<TenantDto>(tenant));
        }
    }
}
