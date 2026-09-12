using AutoMapper;
using IFX.Modules.IAM.Application.Tenancy.Tenants.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tenancy.Tenants.Commands.UpdateTenant;
public class UpdateTenantCommandHandler : IRequestHandler<UpdateTenantCommand, Result<TenantDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<UpdateTenantCommandHandler> _logger;
    public UpdateTenantCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ILogger<UpdateTenantCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<TenantDto>> Handle(UpdateTenantCommand request, CancellationToken cancellationToken)
    {
        {
            var tenant = await _unitOfWork.Tenants.GetByIdAsync(request.TenantId, cancellationToken);
            if (tenant == null)
                return Result<TenantDto>.Failure("Tenant not found");
            if (tenant.Name != request.Name && await _unitOfWork.Tenants.NameExistsAsync(request.Name, request.TenantId, cancellationToken))
                return Result<TenantDto>.Failure($"Tenant '{request.Name}' already exists");
            tenant.Update(request.Name, request.Description);
            _logger.LogInformation("Tenant {TenantId} updated: {Name}", request.TenantId, request.Name);
            return Result<TenantDto>.Success(_mapper.Map<TenantDto>(tenant));
        }
    }
}
