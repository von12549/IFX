using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.IAM.Application.Common;
using IFX.Modules.IAM.Application.Common.DTOs;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Application.Users.DTOs;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.IAM.Application.Users.Queries.GetAllUsersAcrossTenants;

public class GetAllUsersAcrossTenantsQueryHandler
    : IRequestHandler<GetAllUsersAcrossTenantsQuery, Result<CrossTenantResultDto<UserProfileDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IPermissionChecker _permission;
    private readonly ILogger<GetAllUsersAcrossTenantsQueryHandler> _logger;

    public GetAllUsersAcrossTenantsQueryHandler(
        IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser,
        ILogger<GetAllUsersAcrossTenantsQueryHandler> logger, IPermissionChecker permission)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _permission = permission;
        _logger = logger;
    }

    public async Task<Result<CrossTenantResultDto<UserProfileDto>>> Handle(
        GetAllUsersAcrossTenantsQuery request, CancellationToken cancellationToken)
    {
        try
        {
            await CrossTenantAccessGuard.RequireAsync(_currentUser, _permission, cancellationToken);

            var users = await _unitOfWork.Users.GetAcrossTenantsWithTenantsAsync(CrossTenantAccessGuard.MaximumRows, cancellationToken);

            // A user belonging to multiple tenants appears in each relevant group.
            var groups = users
                .SelectMany(u => u.Tenants, (u, t) => (user: u, tenant: t))
                .Where(x => x.tenant.Id != _currentUser.TenantId)
                .GroupBy(x => x.tenant)
                .OrderBy(g => g.Key.Name)
                .Select(g => new TenantGroupDto<UserProfileDto>
                {
                    TenantId = g.Key.Id,
                    TenantName = g.Key.Name,
                    Items = _mapper.Map<List<UserProfileDto>>(
                        g.Select(x => x.user)
                         .DistinctBy(u => u.Id)
                         .OrderBy(u => u.DisplayName)
                         .ToList())
                })
                .ToList();

            _logger.LogWarning(
                "Cross-tenant query {Purpose} executed by {ActorUserId}; limit {MaxRows}; returned {TenantCount} tenant groups",
                "platform-user-inventory", _currentUser.UserId, CrossTenantAccessGuard.MaximumRows, groups.Count);
            return Result<CrossTenantResultDto<UserProfileDto>>.Success(
                new CrossTenantResultDto<UserProfileDto> { Tenants = groups });
        }
        catch (ForbiddenException) { throw; }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving users across tenants");
            return Result<CrossTenantResultDto<UserProfileDto>>.Failure("An error occurred while retrieving cross-tenant users.");
        }
    }
}
