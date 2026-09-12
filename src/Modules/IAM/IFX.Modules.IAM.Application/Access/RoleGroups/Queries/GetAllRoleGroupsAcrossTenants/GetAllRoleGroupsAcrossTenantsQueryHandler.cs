using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.IAM.Application.Access.RoleGroups.DTOs;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Common.DTOs;
using IFX.Modules.IAM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Access.RoleGroups.Queries.GetAllRoleGroupsAcrossTenants;

public class GetAllRoleGroupsAcrossTenantsQueryHandler
    : IRequestHandler<GetAllRoleGroupsAcrossTenantsQuery, Result<CrossTenantResultDto<RoleGroupDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<GetAllRoleGroupsAcrossTenantsQueryHandler> _logger;

    public GetAllRoleGroupsAcrossTenantsQueryHandler(
        IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser,
        ILogger<GetAllRoleGroupsAcrossTenantsQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _logger = logger;
    }

    public async Task<Result<CrossTenantResultDto<RoleGroupDto>>> Handle(
        GetAllRoleGroupsAcrossTenantsQuery request, CancellationToken cancellationToken)
    {
        try
        {
            CrossTenantAccessGuard.Require(_currentUser);

            var groups_raw = await _unitOfWork.RoleGroups.GetAcrossTenantsAsync(CrossTenantAccessGuard.MaximumRows, cancellationToken);

            var groups = groups_raw
                .Where(g => g.Tenant != null && g.TenantId != _currentUser.TenantId)
                .GroupBy(g => g.Tenant!)
                .OrderBy(g => g.Key.Name)
                .Select(g => new TenantGroupDto<RoleGroupDto>
                {
                    TenantId = g.Key.Id,
                    TenantName = g.Key.Name,
                    Items = _mapper.Map<List<RoleGroupDto>>(g.OrderBy(rg => rg.Name).ToList())
                })
                .ToList();

            _logger.LogWarning(
                "Cross-tenant query {Purpose} executed by {ActorUserId}; limit {MaxRows}; returned {TenantCount} tenant groups",
                "platform-role-group-inventory", _currentUser.UserId, CrossTenantAccessGuard.MaximumRows, groups.Count);
            return Result<CrossTenantResultDto<RoleGroupDto>>.Success(
                new CrossTenantResultDto<RoleGroupDto> { Tenants = groups });
        }
        catch (ForbiddenException) { throw; }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving role groups across tenants");
            return Result<CrossTenantResultDto<RoleGroupDto>>.Failure("An error occurred while retrieving cross-tenant role groups.");
        }
    }
}
