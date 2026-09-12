using AutoMapper;
using IFX.Modules.IAM.Application.Tenancy.Tenants.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tenancy.Tenants.Queries.GetTenantById;

public class GetTenantByIdQueryHandler : IRequestHandler<GetTenantByIdQuery, Result<TenantDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ILogger<GetTenantByIdQueryHandler> _logger;

    public GetTenantByIdQueryHandler(IUnitOfWork unitOfWork, IMapper mapper, ILogger<GetTenantByIdQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _logger = logger;
    }

    public async Task<Result<TenantDto>> Handle(GetTenantByIdQuery request, CancellationToken cancellationToken)
    {
        var tenant = await _unitOfWork.Tenants.GetByIdAsync(request.TenantId, cancellationToken);
        if (tenant == null)
            return Result<TenantDto>.Failure("Tenant not found");

        return Result<TenantDto>.Success(_mapper.Map<TenantDto>(tenant));
    }
}
