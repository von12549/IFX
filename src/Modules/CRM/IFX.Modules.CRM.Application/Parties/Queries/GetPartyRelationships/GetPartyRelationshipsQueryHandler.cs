using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Parties.DTOs;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Parties.Queries.GetPartyRelationships;

public class GetPartyRelationshipsQueryHandler : IRequestHandler<GetPartyRelationshipsQuery, Result<IReadOnlyList<PartyRelationshipDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetPartyRelationshipsQueryHandler> _logger;

    public GetPartyRelationshipsQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<GetPartyRelationshipsQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<IReadOnlyList<PartyRelationshipDto>>> Handle(GetPartyRelationshipsQuery request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "party", "read", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null)
                return Result<IReadOnlyList<PartyRelationshipDto>>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;

            var relationships = await _unitOfWork.PartyRelationships.GetByPartyIdAsync(request.PartyId, tenantId, cancellationToken);
            var dtos = _mapper.Map<IReadOnlyList<PartyRelationshipDto>>(relationships);
            return Result<IReadOnlyList<PartyRelationshipDto>>.Success(dtos);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting relationships for party {PartyId}", request.PartyId);
            return Result<IReadOnlyList<PartyRelationshipDto>>.Failure("An error occurred.");
        }
    }
}
