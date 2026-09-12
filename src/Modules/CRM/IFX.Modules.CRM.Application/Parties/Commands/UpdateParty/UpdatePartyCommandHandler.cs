using IFX.Modules.CRM.Application.Ports.Authorization;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Parties.DTOs;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Parties.Commands.UpdateParty;
public class UpdatePartyCommandHandler : IRequestHandler<UpdatePartyCommand, Result<PartyDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<UpdatePartyCommandHandler> _logger;
    public UpdatePartyCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<UpdatePartyCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<PartyDto>> Handle(UpdatePartyCommand request, CancellationToken cancellationToken)
    {
        {
            if (_currentUser.TenantId == null)
                return Result<PartyDto>.Failure("Tenant context is required.");
            var party = await _unitOfWork.Parties.GetByIdAsync(request.PartyId, _currentUser.TenantId.Value, cancellationToken);
            if (party == null)
                return Result<PartyDto>.Failure("Party not found.");
            var resourceAttributes = new TenantScopeResourceAttributes(_currentUser.TenantId);
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("party", "update", resourceAttributes, ct: cancellationToken);
            party.Update(request.Name, request.LegalStructure);
            _logger.LogInformation("Party updated: {PartyId}", request.PartyId);
            return Result<PartyDto>.Success(_mapper.Map<PartyDto>(party));
        }
    }
}
