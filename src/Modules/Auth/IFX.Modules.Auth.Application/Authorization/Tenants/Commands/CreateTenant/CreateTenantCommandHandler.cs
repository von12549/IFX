using AutoMapper;
using IFX.Modules.Auth.Application.Authorization.Tenants.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Tenants.Commands.CreateTenant;
public class CreateTenantCommandHandler : IRequestHandler<CreateTenantCommand, Result<TenantDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<CreateTenantCommandHandler> _logger;
    public CreateTenantCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, ILogger<CreateTenantCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _logger = logger;
    }

    public async Task<Result<TenantDto>> Handle(CreateTenantCommand request, CancellationToken cancellationToken)
    {
        {
            if (await _unitOfWork.Tenants.NameExistsAsync(request.Name, cancellationToken))
                return Result<TenantDto>.Failure($"Tenant '{request.Name}' already exists");
            var tenant = Tenant.Create(request.Name, request.Description);
            tenant.CreatedBy = _currentUser.UserId;
            await _unitOfWork.Tenants.AddAsync(tenant, cancellationToken);
            _logger.LogInformation("Tenant created: {Name}", request.Name);
            return Result<TenantDto>.Success(_mapper.Map<TenantDto>(tenant));
        }
    }
}
