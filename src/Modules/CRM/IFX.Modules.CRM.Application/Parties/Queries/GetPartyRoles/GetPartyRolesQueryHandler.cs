using IFX.Modules.CRM.Application.Ports.Authorization;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Parties.Queries.GetPartyRoles;

public class GetPartyRolesQueryHandler : IRequestHandler<GetPartyRolesQuery, Result<IReadOnlyList<PartyFunctionalRole>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetPartyRolesQueryHandler> _logger;

    public GetPartyRolesQueryHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService, ILogger<GetPartyRolesQueryHandler> logger)
    {
        _unitOfWork = unitOfWork; _currentUser = currentUser;
        _authorizationService = authorizationService; _logger = logger;
    }

    public async Task<Result<IReadOnlyList<PartyFunctionalRole>>> Handle(GetPartyRolesQuery request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "party", "read", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null) return Result<IReadOnlyList<PartyFunctionalRole>>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;

            var assignments = await _unitOfWork.PartyRoleAssignments.GetRolesForPartyAsync(request.PartyId, tenantId, cancellationToken);
            var roles = assignments.Select(a => a.Role).ToList();
            return Result<IReadOnlyList<PartyFunctionalRole>>.Success(roles);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting roles for party {PartyId}", request.PartyId);
            return Result<IReadOnlyList<PartyFunctionalRole>>.Failure("An error occurred.");
        }
    }
}
