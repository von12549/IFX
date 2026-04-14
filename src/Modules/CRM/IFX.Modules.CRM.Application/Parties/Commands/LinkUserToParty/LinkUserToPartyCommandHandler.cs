using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Domain.Entities;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Parties.Commands.LinkUserToParty;

public class LinkUserToPartyCommandHandler : IRequestHandler<LinkUserToPartyCommand, Result<Unit>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<LinkUserToPartyCommandHandler> _logger;

    public LinkUserToPartyCommandHandler(IUnitOfWork unitOfWork, ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService, ILogger<LinkUserToPartyCommandHandler> logger)
    {
        _unitOfWork = unitOfWork; _currentUser = currentUser;
        _authorizationService = authorizationService; _logger = logger;
    }

    public async Task<Result<Unit>> Handle(LinkUserToPartyCommand request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "party", "update", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null) return Result<Unit>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;

            var party = await _unitOfWork.Parties.GetByIdAsync(request.PartyId, tenantId, cancellationToken);
            if (party == null) return Result<Unit>.Failure("Party not found.");

            // UNIQUE(TenantId, UserId) — a user can only have one CRM identity per tenant
            var existingByUser = await _unitOfWork.UserPartyLinks.GetByUserIdAsync(request.UserId, tenantId, cancellationToken);
            if (existingByUser != null)
                return Result<Unit>.Failure("User already has a CRM Party link in this tenant.");

            var link = UserPartyLink.Create(request.UserId, request.PartyId, tenantId);
            link.CreatedBy = _currentUser.UserId;
            await _unitOfWork.UserPartyLinks.AddAsync(link, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("User {UserId} linked to Party {PartyId}", request.UserId, request.PartyId);
            return Result<Unit>.Success(Unit.Value);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error linking user to party");
            return Result<Unit>.Failure("An error occurred.");
        }
    }
}
