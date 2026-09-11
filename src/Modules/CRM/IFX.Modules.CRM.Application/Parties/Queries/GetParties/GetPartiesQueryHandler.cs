using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Parties.DTOs;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Parties.Queries.GetParties;

public class GetPartiesQueryHandler : IRequestHandler<GetPartiesQuery, Result<List<PartyDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetPartiesQueryHandler> _logger;

    public GetPartiesQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<GetPartiesQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<List<PartyDto>>> Handle(GetPartiesQuery request, CancellationToken cancellationToken)
    {
        try
        {
            if (_currentUser.TenantId == null)
                return Result<List<PartyDto>>.Success(new List<PartyDto>());

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "party", "list",
                new TenantScopeResourceAttributes(_currentUser.TenantId),
                ct: cancellationToken);

            var parties = await _unitOfWork.Parties.GetByTenantIdAsync(_currentUser.TenantId.Value, cancellationToken);

            _logger.LogInformation("Retrieved {Count} parties for tenant {TenantId}", parties.Count, _currentUser.TenantId);
            return Result<List<PartyDto>>.Success(_mapper.Map<List<PartyDto>>(parties));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving parties");
            return Result<List<PartyDto>>.Failure("An error occurred while retrieving parties.");
        }
    }
}
