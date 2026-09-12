using IFX.Modules.CRM.Application.Ports.Authorization;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.InvestmentAccounts.DTOs;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Domain.Entities;
using MediatR;
using Microsoft.Extensions.Logging;
using IFX.BuildingBlocks.Application.Events;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.CreateInvestmentAccount;
public class CreateInvestmentAccountCommandHandler : IRequestHandler<CreateInvestmentAccountCommand, Result<InvestmentAccountDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICommittedEventBuffer _eventBuffer;
    private readonly ILogger<CreateInvestmentAccountCommandHandler> _logger;
    public CreateInvestmentAccountCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ICommittedEventBuffer eventBuffer, ILogger<CreateInvestmentAccountCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBuffer = eventBuffer;
        _logger = logger;
    }

    public async Task<Result<InvestmentAccountDto>> Handle(CreateInvestmentAccountCommand request, CancellationToken cancellationToken)
    {
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("investment-account", "create", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            if (_currentUser.TenantId == null)
                return Result<InvestmentAccountDto>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;
            if (await _unitOfWork.InvestmentAccounts.AccountNumberExistsAsync(request.AccountNumber, tenantId, cancellationToken))
                return Result<InvestmentAccountDto>.Failure($"Account number '{request.AccountNumber}' already exists.");
            var account = InvestmentAccount.Create(tenantId, request.AccountNumber, request.AccountType, request.CertificateDate);
            account.CreatedBy = _currentUser.UserId;
            await _unitOfWork.InvestmentAccounts.AddAsync(account, cancellationToken);
            _logger.LogInformation("InvestmentAccount created: {AccountNumber}", account.AccountNumber);
            return Result<InvestmentAccountDto>.Success(_mapper.Map<InvestmentAccountDto>(account));
        }
    }
}
