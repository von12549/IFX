using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.IAM.Application.Tenancy.Departments.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Common.DTOs;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Tenancy.Departments.Queries.GetAllDepartmentsAcrossTenants;

public class GetAllDepartmentsAcrossTenantsQueryHandler
    : IRequestHandler<GetAllDepartmentsAcrossTenantsQuery, Result<CrossTenantResultDto<DepartmentDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IPermissionChecker _permission;
    private readonly ILogger<GetAllDepartmentsAcrossTenantsQueryHandler> _logger;

    public GetAllDepartmentsAcrossTenantsQueryHandler(
        IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser,
        ILogger<GetAllDepartmentsAcrossTenantsQueryHandler> logger, IPermissionChecker permission)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _permission = permission;
        _logger = logger;
    }

    public async Task<Result<CrossTenantResultDto<DepartmentDto>>> Handle(
        GetAllDepartmentsAcrossTenantsQuery request, CancellationToken cancellationToken)
    {
        try
        {
            await CrossTenantAccessGuard.RequireAsync(_currentUser, _permission, cancellationToken);

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
