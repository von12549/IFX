using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.UnlinkPartyFromInvestmentAccount;
public class UnlinkPartyFromInvestmentAccountCommandHandler : IRequestHandler<UnlinkPartyFromInvestmentAccountCommand, Result<Unit>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<UnlinkPartyFromInvestmentAccountCommandHandler> _logger;
    public UnlinkPartyFromInvestmentAccountCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<UnlinkPartyFromInvestmentAccountCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<Unit>> Handle(UnlinkPartyFromInvestmentAccountCommand request, CancellationToken cancellationToken)
    {
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("investment-account", "update", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            if (_currentUser.TenantId == null)
                return Result<Unit>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;
            var link = await _unitOfWork.PartyInvestmentAccountLinks.GetAsync(request.PartyId, request.InvestmentAccountId, tenantId, cancellationToken);
            if (link == null)
                return Result<Unit>.Failure("Party link not found.");
            _unitOfWork.PartyInvestmentAccountLinks.Remove(link);
            return Result<Unit>.Success(Unit.Value);
        }
    }
}
