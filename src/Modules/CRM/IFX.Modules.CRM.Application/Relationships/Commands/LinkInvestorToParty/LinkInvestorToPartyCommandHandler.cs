using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Domain.Entities;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Relationships.Commands.LinkInvestorToParty;

public class LinkInvestorToPartyCommandHandler : IRequestHandler<LinkInvestorToPartyCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<LinkInvestorToPartyCommandHandler> _logger;

    public LinkInvestorToPartyCommandHandler(
        IUnitOfWork unitOfWork,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<LinkInvestorToPartyCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(LinkInvestorToPartyCommand request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "party", "update",
                new TenantScopeResourceAttributes(_currentUser.TenantId),
                ct: cancellationToken);

            if (_currentUser.TenantId == null)
                return Result<bool>.Failure("Tenant context is required.");

            if (await _unitOfWork.PartyInvestors.ExistsAsync(request.PartyId, request.InvestorId, request.RelationshipType, cancellationToken))
                return Result<bool>.Failure("This investor-party relationship already exists.");

            var relationship = PartyInvestorRelationship.Create(
                request.PartyId,
                request.InvestorId,
                _currentUser.TenantId.Value,
                request.RelationshipType,
                request.EffectiveDate);

            await _unitOfWork.PartyInvestors.AddAsync(relationship, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Linked investor {InvestorId} to party {PartyId} with type {RelationshipType}",
                request.InvestorId, request.PartyId, request.RelationshipType);
            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error linking investor {InvestorId} to party {PartyId}", request.InvestorId, request.PartyId);
            return Result<bool>.Failure("An error occurred while linking the investor to the party.");
        }
    }
}
