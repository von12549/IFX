using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.UnlinkAdvisorFromInvestmentAccount;
public class UnlinkAdvisorFromInvestmentAccountCommandHandler : IRequestHandler<UnlinkAdvisorFromInvestmentAccountCommand, Result<Unit>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<UnlinkAdvisorFromInvestmentAccountCommandHandler> _logger;
    public UnlinkAdvisorFromInvestmentAccountCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<UnlinkAdvisorFromInvestmentAccountCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<Unit>> Handle(UnlinkAdvisorFromInvestmentAccountCommand request, CancellationToken cancellationToken)
    {
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("investment-account", "update", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            if (_currentUser.TenantId == null)
                return Result<Unit>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;
            var link = await _unitOfWork.AdvisorInvestmentAccountLinks.GetAsync(request.AdvisorPartyId, request.InvestmentAccountId, tenantId, cancellationToken);
            if (link == null)
                return Result<Unit>.Failure("Advisor link not found.");
            _unitOfWork.AdvisorInvestmentAccountLinks.Remove(link);
            return Result<Unit>.Success(Unit.Value);
        }
    }
}
