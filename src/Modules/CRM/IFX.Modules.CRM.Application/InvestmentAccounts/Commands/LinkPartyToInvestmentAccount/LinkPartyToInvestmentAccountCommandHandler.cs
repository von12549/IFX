using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Domain.Entities;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.LinkPartyToInvestmentAccount;

public class LinkPartyToInvestmentAccountCommandHandler : IRequestHandler<LinkPartyToInvestmentAccountCommand, Result<Unit>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<LinkPartyToInvestmentAccountCommandHandler> _logger;

    public LinkPartyToInvestmentAccountCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService, ILogger<LinkPartyToInvestmentAccountCommandHandler> logger)
    {
        _unitOfWork = unitOfWork; _currentUser = currentUser;
        _authorizationService = authorizationService; _logger = logger;
    }

    public async Task<Result<Unit>> Handle(LinkPartyToInvestmentAccountCommand request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "investment-account", "update", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null) return Result<Unit>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;

            var account = await _unitOfWork.InvestmentAccounts.GetByIdAsync(request.InvestmentAccountId, tenantId, cancellationToken);
            if (account == null) return Result<Unit>.Failure("Investment account not found.");

            var party = await _unitOfWork.Parties.GetByIdAsync(request.PartyId, tenantId, cancellationToken);
            if (party == null) return Result<Unit>.Failure("Party not found.");

            var existingLinks = await _unitOfWork.PartyInvestmentAccountLinks.GetLinksByAccountIdAsync(request.InvestmentAccountId, tenantId, cancellationToken);

            if (request.RelationshipType == InvestmentAccountRelationshipType.RegisteredHolder
                && account.AccountType != InvestmentAccountType.Joint
                && existingLinks.Any(l => l.RelationshipType == InvestmentAccountRelationshipType.RegisteredHolder))
                return Result<Unit>.Failure("A non-joint account may only have one RegisteredHolder.");

            if (request.LinkOrder.HasValue && existingLinks.Any(l => l.LinkOrder == request.LinkOrder))
                return Result<Unit>.Failure($"LinkOrder {request.LinkOrder} is already assigned to another party on this account.");

            if (request.OwnershipPercentage.HasValue)
            {
                var existingTotal = existingLinks
                    .Where(l => l.RelationshipType == InvestmentAccountRelationshipType.RegisteredHolder)
                    .Sum(l => l.OwnershipPercentage ?? 0m);
                if (existingTotal + request.OwnershipPercentage.Value > 100m)
                    return Result<Unit>.Failure("Total ownership percentage cannot exceed 100%.");
            }

            var link = PartyInvestmentAccountLink.Create(tenantId, request.PartyId, request.InvestmentAccountId,
                request.RelationshipType, request.EffectiveDate, request.OwnershipPercentage, request.LinkOrder);
            link.CreatedBy = _currentUser.UserId;

            await _unitOfWork.PartyInvestmentAccountLinks.AddAsync(link, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            return Result<Unit>.Success(Unit.Value);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error linking party {PartyId} to account {AccountId}", request.PartyId, request.InvestmentAccountId);
            return Result<Unit>.Failure("An error occurred.");
        }
    }
}
