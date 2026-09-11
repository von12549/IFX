using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.InvestmentAccounts.DTOs;
using IFX.Modules.CRM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Queries.GetInvestmentAccounts;

public class GetInvestmentAccountsQueryHandler : IRequestHandler<GetInvestmentAccountsQuery, Result<IReadOnlyList<InvestmentAccountDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetInvestmentAccountsQueryHandler> _logger;

    public GetInvestmentAccountsQueryHandler(IUnitOfWork unitOfWork, IMapper mapper,
        ICurrentUser currentUser, IResourceAuthorizationService authorizationService,
        ILogger<GetInvestmentAccountsQueryHandler> logger)
    {
        _unitOfWork = unitOfWork; _mapper = mapper; _currentUser = currentUser;
        _authorizationService = authorizationService; _logger = logger;
    }

    public async Task<Result<IReadOnlyList<InvestmentAccountDto>>> Handle(GetInvestmentAccountsQuery request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "investment-account", "list", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null) return Result<IReadOnlyList<InvestmentAccountDto>>.Failure("Tenant context required.");
            var accounts = await _unitOfWork.InvestmentAccounts.GetByTenantAsync(_currentUser.TenantId.Value, cancellationToken);
            return Result<IReadOnlyList<InvestmentAccountDto>>.Success(_mapper.Map<IReadOnlyList<InvestmentAccountDto>>(accounts));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error listing investment accounts");
            return Result<IReadOnlyList<InvestmentAccountDto>>.Failure("An error occurred.");
        }
    }
}
