using IFX.Modules.CRM.Application.Ports.Authorization;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Parties.Commands.UnlinkUserFromParty;
public class UnlinkUserFromPartyCommandHandler : IRequestHandler<UnlinkUserFromPartyCommand, Result<Unit>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<UnlinkUserFromPartyCommandHandler> _logger;
    public UnlinkUserFromPartyCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<UnlinkUserFromPartyCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<Unit>> Handle(UnlinkUserFromPartyCommand request, CancellationToken cancellationToken)
    {
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("party", "update", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            if (_currentUser.TenantId == null)
                return Result<Unit>.Failure("Tenant context required.");
            var link = await _unitOfWork.UserPartyLinks.GetByUserIdAsync(request.UserId, _currentUser.TenantId.Value, cancellationToken);
            if (link == null)
                return Result<Unit>.Failure("User party link not found.");
            _unitOfWork.UserPartyLinks.Remove(link);
            return Result<Unit>.Success(Unit.Value);
        }
    }
}
