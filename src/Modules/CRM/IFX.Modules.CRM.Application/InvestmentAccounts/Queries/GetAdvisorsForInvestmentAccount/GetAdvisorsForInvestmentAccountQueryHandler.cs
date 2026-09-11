using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Application.InvestmentAccounts.DTOs;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Queries.GetAdvisorsForInvestmentAccount;

public class GetAdvisorsForInvestmentAccountQueryHandler : IRequestHandler<GetAdvisorsForInvestmentAccountQuery, Result<IReadOnlyList<AdvisorLinkDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetAdvisorsForInvestmentAccountQueryHandler> _logger;

    public GetAdvisorsForInvestmentAccountQueryHandler(
        IUnitOfWork unitOfWork,
        IMapper mapper,
        ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ILogger<GetAdvisorsForInvestmentAccountQueryHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<IReadOnlyList<AdvisorLinkDto>>> Handle(GetAdvisorsForInvestmentAccountQuery request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "investment-account", "read", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null)
                return Result<IReadOnlyList<AdvisorLinkDto>>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;

            var links = await _unitOfWork.AdvisorInvestmentAccountLinks.GetByAccountIdAsync(request.InvestmentAccountId, tenantId, cancellationToken);
            var dtos = _mapper.Map<IReadOnlyList<AdvisorLinkDto>>(links);
            return Result<IReadOnlyList<AdvisorLinkDto>>.Success(dtos);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting advisors for investment account {InvestmentAccountId}", request.InvestmentAccountId);
            return Result<IReadOnlyList<AdvisorLinkDto>>.Failure("An error occurred.");
        }
    }
}
