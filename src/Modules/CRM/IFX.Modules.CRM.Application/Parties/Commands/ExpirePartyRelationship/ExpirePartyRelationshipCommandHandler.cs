using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Parties.Commands.ExpirePartyRelationship;

public class ExpirePartyRelationshipCommandHandler : IRequestHandler<ExpirePartyRelationshipCommand, Result<Unit>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<ExpirePartyRelationshipCommandHandler> _logger;

    public ExpirePartyRelationshipCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService, ILogger<ExpirePartyRelationshipCommandHandler> logger)
    {
        _unitOfWork = unitOfWork; _currentUser = currentUser;
        _authorizationService = authorizationService; _logger = logger;
    }

    public async Task<Result<Unit>> Handle(ExpirePartyRelationshipCommand request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "party", "update", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null) return Result<Unit>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;

            var relationship = await _unitOfWork.PartyRelationships.GetByIdAsync(request.RelationshipId, tenantId, cancellationToken);
            if (relationship == null) return Result<Unit>.Failure("Party relationship not found.");

            relationship.Expire(request.ExpiryDate);
            relationship.UpdatedBy = _currentUser.UserId;
            _unitOfWork.PartyRelationships.Update(relationship);
            await _unitOfWork.SaveChangesAsync(cancellationToken);
            return Result<Unit>.Success(Unit.Value);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error expiring party relationship {Id}", request.RelationshipId);
            return Result<Unit>.Failure("An error occurred.");
        }
    }
}
