using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.InvestmentAccounts.DTOs;
using IFX.Modules.CRM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Queries.GetInvestmentAccountById;

public class GetInvestmentAccountByIdQueryHandler : IRequestHandler<GetInvestmentAccountByIdQuery, Result<InvestmentAccountDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<GetInvestmentAccountByIdQueryHandler> _logger;

    public GetInvestmentAccountByIdQueryHandler(IUnitOfWork unitOfWork, IMapper mapper,
        ICurrentUser currentUser, IResourceAuthorizationService authorizationService,
        ILogger<GetInvestmentAccountByIdQueryHandler> logger)
    {
        _unitOfWork = unitOfWork; _mapper = mapper; _currentUser = currentUser;
        _authorizationService = authorizationService; _logger = logger;
    }

    public async Task<Result<InvestmentAccountDto>> Handle(GetInvestmentAccountByIdQuery request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "investment-account", "read", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null) return Result<InvestmentAccountDto>.Failure("Tenant context required.");
            var account = await _unitOfWork.InvestmentAccounts.GetByIdAsync(request.Id, _currentUser.TenantId.Value, cancellationToken);
            if (account == null) return Result<InvestmentAccountDto>.Failure("Investment account not found.");
            return Result<InvestmentAccountDto>.Success(_mapper.Map<InvestmentAccountDto>(account));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting investment account {Id}", request.Id);
            return Result<InvestmentAccountDto>.Failure("An error occurred.");
        }
    }
}
