using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Common.Authorization;
using IFX.Modules.CRM.Application.InvestmentAccounts.DTOs;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Domain.Entities;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.CreateInvestmentAccount;

public class CreateInvestmentAccountCommandHandler : IRequestHandler<CreateInvestmentAccountCommand, Result<InvestmentAccountDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ILogger<CreateInvestmentAccountCommandHandler> _logger;

    public CreateInvestmentAccountCommandHandler(IUnitOfWork unitOfWork, IMapper mapper,
        ICurrentUser currentUser, IResourceAuthorizationService authorizationService,
        ILogger<CreateInvestmentAccountCommandHandler> logger)
    {
        _unitOfWork = unitOfWork; _mapper = mapper; _currentUser = currentUser;
        _authorizationService = authorizationService; _logger = logger;
    }

    public async Task<Result<InvestmentAccountDto>> Handle(CreateInvestmentAccountCommand request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "investment-account", "create", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null) return Result<InvestmentAccountDto>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;

            if (await _unitOfWork.InvestmentAccounts.AccountNumberExistsAsync(request.AccountNumber, tenantId, cancellationToken))
                return Result<InvestmentAccountDto>.Failure($"Account number '{request.AccountNumber}' already exists.");

            var account = InvestmentAccount.Create(tenantId, request.AccountNumber, request.AccountType, request.CertificateDate);
            account.CreatedBy = _currentUser.UserId;

            await _unitOfWork.InvestmentAccounts.AddAsync(account, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            _logger.LogInformation("InvestmentAccount created: {AccountNumber}", account.AccountNumber);
            return Result<InvestmentAccountDto>.Success(_mapper.Map<InvestmentAccountDto>(account));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating investment account");
            return Result<InvestmentAccountDto>.Failure("An error occurred while creating the investment account.");
        }
    }
}
