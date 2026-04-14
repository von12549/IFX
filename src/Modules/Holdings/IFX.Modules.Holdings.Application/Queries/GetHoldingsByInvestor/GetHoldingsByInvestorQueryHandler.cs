using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Holdings.Abstractions.DTOs;
using IFX.Modules.Holdings.Application.Common;
using IFX.Modules.Holdings.Application.Common.Authorization;
using IFX.Modules.Holdings.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Holdings.Application.Queries.GetHoldingsByInvestor;

public class GetHoldingsByInvestorQueryHandler : IRequestHandler<GetHoldingsByInvestorQuery, Result<IReadOnlyList<HoldingSummaryDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetHoldingsByInvestorQueryHandler> _logger;

    public GetHoldingsByInvestorQueryHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService, ILogger<GetHoldingsByInvestorQueryHandler> logger)
    {
        _unitOfWork = unitOfWork; _mapper = mapper; _currentUser = currentUser;
        _authorizationService = authorizationService; _logger = logger;
    }

    public async Task<Result<IReadOnlyList<HoldingSummaryDto>>> Handle(GetHoldingsByInvestorQuery request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "holding", "list", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null)
                return Result<IReadOnlyList<HoldingSummaryDto>>.Failure("Tenant context required.");

            var holdings = await _unitOfWork.Holdings.GetByInvestmentAccountAsync(_currentUser.TenantId.Value, request.InvestmentAccountId, cancellationToken);
            var dtos = _mapper.Map<IReadOnlyList<HoldingSummaryDto>>(holdings);
            return Result<IReadOnlyList<HoldingSummaryDto>>.Success(dtos);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting holdings for investment account {InvestmentAccountId}", request.InvestmentAccountId);
            return Result<IReadOnlyList<HoldingSummaryDto>>.Failure("An error occurred.");
        }
    }
}
