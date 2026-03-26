using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;
using IFX.Modules.Auth.Application.Common;
using IFX.Modules.Auth.Application.Common.DTOs;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Application.Users.DTOs;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Auth.Application.Users.Queries.GetAllUsersAcrossTenants;

public class GetAllUsersAcrossTenantsQueryHandler
    : IRequestHandler<GetAllUsersAcrossTenantsQuery, Result<CrossTenantResultDto<UserProfileDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<GetAllUsersAcrossTenantsQueryHandler> _logger;

    public GetAllUsersAcrossTenantsQueryHandler(
        IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser,
        ILogger<GetAllUsersAcrossTenantsQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _logger = logger;
    }

    public async Task<Result<CrossTenantResultDto<UserProfileDto>>> Handle(
        GetAllUsersAcrossTenantsQuery request, CancellationToken cancellationToken)
    {
        try
        {
            if (_currentUser.GlobalRoles.Count == 0)
                throw new ForbiddenException("GlobalRole required for cross-tenant access.");

            var users = await _unitOfWork.Users.GetAllUsersWithTenantsAsync(cancellationToken);

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

            _logger.LogInformation("Retrieved users across {TenantCount} tenants", groups.Count);
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
