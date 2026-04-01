using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Abstractions.Events;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Parties.DTOs;
using IFX.Modules.CRM.Domain.Entities;
using IFX.Platform.Messaging.Abstractions;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Parties.Commands.CreateParty;

public class CreatePartyCommandHandler : IRequestHandler<CreatePartyCommand, Result<PartyDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly IIntegrationEventBus _eventBus;
    private readonly ILogger<CreatePartyCommandHandler> _logger;

    public CreatePartyCommandHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        IIntegrationEventBus eventBus,
        ILogger<CreatePartyCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBus = eventBus;
        _logger = logger;
    }

    public async Task<Result<PartyDto>> Handle(CreatePartyCommand request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "party", "create",
                new TenantScopeResourceAttributes(_currentUser.TenantId),
                ct: cancellationToken);

            if (_currentUser.TenantId == null)
                return Result<PartyDto>.Failure("Tenant context is required.");

            if (await _unitOfWork.Parties.CodeExistsAsync(request.PartyCode, _currentUser.TenantId.Value, cancellationToken))
                return Result<PartyDto>.Failure($"Party code '{request.PartyCode}' already exists in this tenant.");

            var party = Party.Create(_currentUser.TenantId.Value, request.PartyCode, request.Name, request.Type);
            party.CreatedBy = _currentUser.UserId;

            await _unitOfWork.Parties.AddAsync(party, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            await _eventBus.PublishAsync(new PartyCreatedEvent(party.Id, party.TenantId, party.PartyCode, party.Name), cancellationToken);

            _logger.LogInformation("Party created: {PartyCode} in tenant {TenantId}", party.PartyCode, party.TenantId);
            return Result<PartyDto>.Success(_mapper.Map<PartyDto>(party));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating party {PartyCode}", request.PartyCode);
            return Result<PartyDto>.Failure("An error occurred while creating the party.");
        }
    }
}
