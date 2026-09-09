using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.Auth.Application.Authorization.Roles.DTOs;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Common.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Authorization.Roles.Queries.GetAllRolesAcrossTenants;

public class GetAllRolesAcrossTenantsQueryHandler
    : IRequestHandler<GetAllRolesAcrossTenantsQuery, Result<CrossTenantResultDto<RoleDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<GetAllRolesAcrossTenantsQueryHandler> _logger;

    public GetAllRolesAcrossTenantsQueryHandler(
        IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser,
        ILogger<GetAllRolesAcrossTenantsQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _logger = logger;
    }

    public async Task<Result<CrossTenantResultDto<RoleDto>>> Handle(
        GetAllRolesAcrossTenantsQuery request, CancellationToken cancellationToken)
    {
        try
        {
            CrossTenantAccessGuard.Require(_currentUser);

            var roles = await _unitOfWork.Roles.GetAcrossTenantsAsync(CrossTenantAccessGuard.MaximumRows, cancellationToken);

            var groups = roles
                .Where(r => r.Tenant != null && r.TenantId != _currentUser.TenantId)
                .GroupBy(r => r.Tenant!)
                .OrderBy(g => g.Key.Name)
                .Select(g => new TenantGroupDto<RoleDto>
                {
                    TenantId = g.Key.Id,
                    TenantName = g.Key.Name,
                    Items = _mapper.Map<List<RoleDto>>(g.OrderBy(r => r.Name).ToList())
                })
                .ToList();

            _logger.LogWarning(
                "Cross-tenant query {Purpose} executed by {ActorUserId}; limit {MaxRows}; returned {TenantCount} tenant groups",
                "platform-role-inventory", _currentUser.UserId, CrossTenantAccessGuard.MaximumRows, groups.Count);
            return Result<CrossTenantResultDto<RoleDto>>.Success(new CrossTenantResultDto<RoleDto> { Tenants = groups });
        }
        catch (ForbiddenException) { throw; }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving roles across tenants");
            return Result<CrossTenantResultDto<RoleDto>>.Failure("An error occurred while retrieving cross-tenant roles.");
        }
    }
}
