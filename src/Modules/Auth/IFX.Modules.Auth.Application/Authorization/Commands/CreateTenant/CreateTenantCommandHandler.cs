using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Commands.CreateTenant;

public class CreateTenantCommandHandler : IRequestHandler<CreateTenantCommand, Result<TenantDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<CreateTenantCommandHandler> _logger;

    public CreateTenantCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ILogger<CreateTenantCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<TenantDto>> Handle(CreateTenantCommand request, CancellationToken cancellationToken)
    {
        try
        {
            if (await _unitOfWork.Tenants.NameExistsAsync(request.Name, cancellationToken))
                return Result<TenantDto>.Failure($"Tenant '{request.Name}' already exists");

            var tenant = Tenant.Create(request.Name, request.Description);
            await _unitOfWork.Tenants.AddAsync(tenant, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Tenant created: {Name}", request.Name);
            return Result<TenantDto>.Success(_mapper.Map<TenantDto>(tenant));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating tenant {Name}", request.Name);
            return Result<TenantDto>.Failure("An error occurred while creating the tenant");
        }
    }
}
