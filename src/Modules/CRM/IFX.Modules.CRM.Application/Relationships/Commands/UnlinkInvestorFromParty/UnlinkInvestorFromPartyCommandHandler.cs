using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Relationships.Commands.UnlinkInvestorFromParty;

public class UnlinkInvestorFromPartyCommandHandler : IRequestHandler<UnlinkInvestorFromPartyCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<UnlinkInvestorFromPartyCommandHandler> _logger;

    public UnlinkInvestorFromPartyCommandHandler(
        IUnitOfWork unitOfWork,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<UnlinkInvestorFromPartyCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(UnlinkInvestorFromPartyCommand request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "party", "update",
                new TenantScopeResourceAttributes(_currentUser.TenantId),
                ct: cancellationToken);

            var relationship = await _unitOfWork.PartyInvestors.GetAsync(request.PartyId, request.InvestorId, request.RelationshipType, cancellationToken);
            if (relationship == null)
                return Result<bool>.Failure("Relationship not found.");

            _unitOfWork.PartyInvestors.Remove(relationship);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("Unlinked investor {InvestorId} from party {PartyId} with type {RelationshipType}",
                request.InvestorId, request.PartyId, request.RelationshipType);
            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error unlinking investor {InvestorId} from party {PartyId}", request.InvestorId, request.PartyId);
            return Result<bool>.Failure("An error occurred while unlinking the investor from the party.");
        }
    }
}
