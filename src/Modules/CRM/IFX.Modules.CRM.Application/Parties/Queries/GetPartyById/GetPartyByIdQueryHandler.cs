using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;

using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Parties.DTOs;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Parties.Queries.GetPartyById;

public class GetPartyByIdQueryHandler : IRequestHandler<GetPartyByIdQuery, Result<PartyDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetPartyByIdQueryHandler> _logger;

    public GetPartyByIdQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<GetPartyByIdQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<PartyDto>> Handle(GetPartyByIdQuery request, CancellationToken cancellationToken)
    {
        try
        {
            if (_currentUser.TenantId == null)
                return Result<PartyDto>.Failure("Tenant context is required.");

            var party = await _unitOfWork.Parties.GetByIdAsync(request.PartyId, _currentUser.TenantId.Value, cancellationToken);
            if (party == null)
                return Result<PartyDto>.Failure("Party not found.");

            var resourceAttributes = new TenantScopeResourceAttributes(_currentUser.TenantId);

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "party", "read",
                resourceAttributes,
                ct: cancellationToken);

            return Result<PartyDto>.Success(_mapper.Map<PartyDto>(party));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving party {PartyId}", request.PartyId);
            return Result<PartyDto>.Failure("An error occurred while retrieving the party.");
        }
    }
}
