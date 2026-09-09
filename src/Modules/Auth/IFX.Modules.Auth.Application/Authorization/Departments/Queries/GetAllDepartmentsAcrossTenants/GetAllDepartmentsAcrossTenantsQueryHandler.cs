using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.Auth.Application.Authorization.Departments.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Common.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Departments.Queries.GetAllDepartmentsAcrossTenants;

public class GetAllDepartmentsAcrossTenantsQueryHandler
    : IRequestHandler<GetAllDepartmentsAcrossTenantsQuery, Result<CrossTenantResultDto<DepartmentDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<GetAllDepartmentsAcrossTenantsQueryHandler> _logger;

    public GetAllDepartmentsAcrossTenantsQueryHandler(
        IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser,
        ILogger<GetAllDepartmentsAcrossTenantsQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _logger = logger;
    }

    public async Task<Result<CrossTenantResultDto<DepartmentDto>>> Handle(
        GetAllDepartmentsAcrossTenantsQuery request, CancellationToken cancellationToken)
    {
        try
        {
            CrossTenantAccessGuard.Require(_currentUser);

            var departments = await _unitOfWork.Departments.GetAcrossTenantsAsync(CrossTenantAccessGuard.MaximumRows, cancellationToken);

            var groups = departments
                .Where(d => d.Tenant != null && d.TenantId != _currentUser.TenantId)
                .GroupBy(d => d.Tenant!)
                .OrderBy(g => g.Key.Name)
                .Select(g => new TenantGroupDto<DepartmentDto>
                {
                    TenantId = g.Key.Id,
                    TenantName = g.Key.Name,
                    Items = _mapper.Map<List<DepartmentDto>>(g.OrderBy(d => d.Name).ToList())
                })
                .ToList();

            _logger.LogWarning(
                "Cross-tenant query {Purpose} executed by {ActorUserId}; limit {MaxRows}; returned {TenantCount} tenant groups",
                "platform-department-inventory", _currentUser.UserId, CrossTenantAccessGuard.MaximumRows, groups.Count);
            return Result<CrossTenantResultDto<DepartmentDto>>.Success(
                new CrossTenantResultDto<DepartmentDto> { Tenants = groups });
        }
        catch (ForbiddenException) { throw; }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving departments across tenants");
            return Result<CrossTenantResultDto<DepartmentDto>>.Failure("An error occurred while retrieving cross-tenant departments.");
        }
    }
}
