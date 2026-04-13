using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Parties.Queries.GetPartyForUser;

public class GetPartyForUserQueryHandler : IRequestHandler<GetPartyForUserQuery, Result<Guid?>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetPartyForUserQueryHandler> _logger;

    public GetPartyForUserQueryHandler(
        IUnitOfWork unitOfWork,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<GetPartyForUserQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<Guid?>> Handle(GetPartyForUserQuery request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "party", "read", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null)
                return Result<Guid?>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;

            var link = await _unitOfWork.UserPartyLinks.GetByUserIdAsync(request.UserId, tenantId, cancellationToken);
            return Result<Guid?>.Success(link?.PartyId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting party for user {UserId}", request.UserId);
            return Result<Guid?>.Failure("An error occurred.");
        }
    }
}
