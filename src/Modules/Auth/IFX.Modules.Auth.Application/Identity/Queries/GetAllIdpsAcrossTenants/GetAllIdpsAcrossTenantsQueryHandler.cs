using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Common.DTOs;
using IFX.Modules.Auth.Application.Identity.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Identity.Queries.GetAllIdpsAcrossTenants;

public class GetAllIdpsAcrossTenantsQueryHandler
    : IRequestHandler<GetAllIdpsAcrossTenantsQuery, Result<CrossTenantResultDto<IdpDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<GetAllIdpsAcrossTenantsQueryHandler> _logger;

    public GetAllIdpsAcrossTenantsQueryHandler(
        IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser,
        ILogger<GetAllIdpsAcrossTenantsQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _logger = logger;
    }

    public async Task<Result<CrossTenantResultDto<IdpDto>>> Handle(
        GetAllIdpsAcrossTenantsQuery request, CancellationToken cancellationToken)
    {
        try
        {
            if (_currentUser.GlobalRoles.Count == 0)
                throw new ForbiddenException("GlobalRole required for cross-tenant access.");

            var idps = await _unitOfWork.Idps.GetAllAsync(cancellationToken);

            var groups = idps
                .Where(i => i.Tenant != null && i.TenantId != _currentUser.TenantId)
                .GroupBy(i => i.Tenant!)
                .OrderBy(g => g.Key.Name)
                .Select(g => new TenantGroupDto<IdpDto>
                {
                    TenantId = g.Key.Id,
                    TenantName = g.Key.Name,
                    Items = _mapper.Map<List<IdpDto>>(g.OrderBy(i => i.Name).ToList())
                })
                .ToList();

            _logger.LogInformation("Retrieved IdPs across {TenantCount} tenants", groups.Count);
            return Result<CrossTenantResultDto<IdpDto>>.Success(
                new CrossTenantResultDto<IdpDto> { Tenants = groups });
        }
        catch (ForbiddenException) { throw; }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving IdPs across tenants");
            return Result<CrossTenantResultDto<IdpDto>>.Failure("An error occurred while retrieving cross-tenant IdPs.");
        }
    }
}
