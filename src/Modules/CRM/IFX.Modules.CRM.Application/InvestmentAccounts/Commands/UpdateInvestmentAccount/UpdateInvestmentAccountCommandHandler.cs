using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.InvestmentAccounts.DTOs;
using IFX.Modules.CRM.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.UpdateInvestmentAccount;
public class UpdateInvestmentAccountCommandHandler : IRequestHandler<UpdateInvestmentAccountCommand, Result<InvestmentAccountDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<UpdateInvestmentAccountCommandHandler> _logger;
    public UpdateInvestmentAccountCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ILogger<UpdateInvestmentAccountCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _logger = logger;
    }

    public async Task<Result<InvestmentAccountDto>> Handle(UpdateInvestmentAccountCommand request, CancellationToken cancellationToken)
    {
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("investment-account", "update", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            if (_currentUser.TenantId == null)
                return Result<InvestmentAccountDto>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;
            var account = await _unitOfWork.InvestmentAccounts.GetByIdAsync(request.Id, tenantId, cancellationToken);
            if (account == null)
                return Result<InvestmentAccountDto>.Failure("Investment account not found.");
            if (await _unitOfWork.InvestmentAccounts.AccountNumberExistsAsync(request.AccountNumber, tenantId, request.Id, cancellationToken))
                return Result<InvestmentAccountDto>.Failure($"Account number '{request.AccountNumber}' already exists.");
            account.Update(request.AccountNumber, request.AccountType, request.CertificateDate);
            account.UpdatedBy = _currentUser.UserId;
            _unitOfWork.InvestmentAccounts.Update(account);
            return Result<InvestmentAccountDto>.Success(_mapper.Map<InvestmentAccountDto>(account));
        }
    }
}
