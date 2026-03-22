using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Commands.UpdateTenant;

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
        try
        {
            var tenant = await _unitOfWork.Tenants.GetByIdAsync(request.TenantId, cancellationToken);
            if (tenant == null)
                return Result<TenantDto>.Failure("Tenant not found");

            if (tenant.Name != request.Name &&
                await _unitOfWork.Tenants.NameExistsAsync(request.Name, request.TenantId, cancellationToken))
                return Result<TenantDto>.Failure($"Tenant '{request.Name}' already exists");

            tenant.Update(request.Name, request.Description);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Tenant {TenantId} updated: {Name}", request.TenantId, request.Name);
            return Result<TenantDto>.Success(_mapper.Map<TenantDto>(tenant));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error updating tenant {TenantId}", request.TenantId);
            return Result<TenantDto>.Failure("An error occurred while updating the tenant");
        }
    }
}
