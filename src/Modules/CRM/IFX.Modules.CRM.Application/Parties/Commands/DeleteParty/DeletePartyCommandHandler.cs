using IFX.BuildingBlocks.Security.Authorization.Abstractions;

using IFX.Modules.CRM.Abstractions.Events;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Platform.Messaging.Abstractions;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Parties.Commands.DeleteParty;

public class DeletePartyCommandHandler : IRequestHandler<DeletePartyCommand, Result<bool>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly IIntegrationEventBus _eventBus;
    private readonly ILogger<DeletePartyCommandHandler> _logger;

    public DeletePartyCommandHandler(
        IUnitOfWork unitOfWork,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        IIntegrationEventBus eventBus,
        ILogger<DeletePartyCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBus = eventBus;
        _logger = logger;
    }

    public async Task<Result<bool>> Handle(DeletePartyCommand request, CancellationToken cancellationToken)
    {
        try
        {
            if (_currentUser.TenantId == null)
                return Result<bool>.Failure("Tenant context is required.");

            var party = await _unitOfWork.Parties.GetByIdAsync(request.PartyId, _currentUser.TenantId.Value, cancellationToken);
            if (party == null)
                return Result<bool>.Failure("Party not found.");

            var resourceAttributes = new TenantScopeResourceAttributes(_currentUser.TenantId);

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "party", "delete",
                resourceAttributes,
                ct: cancellationToken);

            var oldStatus = party.Status.ToString();
            party.Close();

            await _unitOfWork.SaveChangesAsync(cancellationToken);

            await _eventBus.PublishAsync(new PartyStatusChangedEvent(party.Id, party.TenantId, oldStatus, party.Status.ToString()), cancellationToken);

            _logger.LogInformation("Party closed: {PartyId}", request.PartyId);
            return Result<bool>.Success(true);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error closing party {PartyId}", request.PartyId);
            return Result<bool>.Failure("An error occurred while closing the party.");
        }
    }
}
