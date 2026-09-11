using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.Investors.DTOs;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.Investors.Queries.GetInvestorsByParty;

public class GetInvestorsByPartyQueryHandler : IRequestHandler<GetInvestorsByPartyQuery, Result<List<InvestorDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetInvestorsByPartyQueryHandler> _logger;

    public GetInvestorsByPartyQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<GetInvestorsByPartyQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<List<InvestorDto>>> Handle(GetInvestorsByPartyQuery request, CancellationToken cancellationToken)
    {
        try
        {
            if (_currentUser.TenantId == null)
                return Result<List<InvestorDto>>.Success(new List<InvestorDto>());

            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "investor", "list",
                new TenantScopeResourceAttributes(_currentUser.TenantId),
                ct: cancellationToken);

            var investors = await _unitOfWork.Investors.GetByPartyIdAsync(request.PartyId, _currentUser.TenantId.Value, cancellationToken);

            _logger.LogInformation("Retrieved {Count} investors for party {PartyId}", investors.Count, request.PartyId);
            return Result<List<InvestorDto>>.Success(_mapper.Map<List<InvestorDto>>(investors));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving investors for party {PartyId}", request.PartyId);
            return Result<List<InvestorDto>>.Failure("An error occurred while retrieving investors for the party.");
        }
    }
}
