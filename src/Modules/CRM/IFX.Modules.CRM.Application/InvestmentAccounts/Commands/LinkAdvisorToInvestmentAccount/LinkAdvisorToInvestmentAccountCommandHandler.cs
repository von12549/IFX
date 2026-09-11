using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.LinkAdvisorToInvestmentAccount;
public class LinkAdvisorToInvestmentAccountCommandHandler : IRequestHandler<LinkAdvisorToInvestmentAccountCommand, Result<Unit>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<LinkAdvisorToInvestmentAccountCommandHandler> _logger;
    public LinkAdvisorToInvestmentAccountCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<LinkAdvisorToInvestmentAccountCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<Unit>> Handle(LinkAdvisorToInvestmentAccountCommand request, CancellationToken cancellationToken)
    {
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("investment-account", "update", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            if (_currentUser.TenantId == null)
                return Result<Unit>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;
            var account = await _unitOfWork.InvestmentAccounts.GetByIdAsync(request.InvestmentAccountId, tenantId, cancellationToken);
            if (account == null)
                return Result<Unit>.Failure("Investment account not found.");
            var hasAdvisoryRole = await _unitOfWork.PartyRoleAssignments.HasRoleAsync(request.AdvisorPartyId, PartyFunctionalRole.AdvisoryFirm, tenantId, cancellationToken) || await _unitOfWork.PartyRoleAssignments.HasRoleAsync(request.AdvisorPartyId, PartyFunctionalRole.AdvisoryBranch, tenantId, cancellationToken) || await _unitOfWork.PartyRoleAssignments.HasRoleAsync(request.AdvisorPartyId, PartyFunctionalRole.AdvisorRep, tenantId, cancellationToken);
            if (!hasAdvisoryRole)
                return Result<Unit>.Failure("Advisor party must have an advisory role (AdvisoryFirm, AdvisoryBranch, or AdvisorRep).");
            var existing = await _unitOfWork.AdvisorInvestmentAccountLinks.GetAsync(request.AdvisorPartyId, request.InvestmentAccountId, tenantId, cancellationToken);
            if (existing != null && existing.ExpiryDate == null)
                return Result<Unit>.Failure("Advisor is already linked to this account.");
            var link = AdvisorInvestmentAccountLink.Create(tenantId, request.AdvisorPartyId, request.InvestmentAccountId, request.EffectiveDate, request.RebateRate);
            link.CreatedBy = _currentUser.UserId;
            await _unitOfWork.AdvisorInvestmentAccountLinks.AddAsync(link, cancellationToken);
            return Result<Unit>.Success(Unit.Value);
        }
    }
}
