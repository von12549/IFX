using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Abstractions.Interfaces;
using IFX.Modules.Registry.Abstractions.Interfaces;
using IFX.Modules.Transaction.Abstractions.Events;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.Common.Authorization;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Platform.Messaging.Abstractions;
using MediatR;
using Microsoft.Extensions.Logging;
using TxEntity = IFX.Modules.Transaction.Domain.Entities.Transaction;

namespace IFX.Modules.Transaction.Application.Commands.CreateSwitch;

public class CreateSwitchCommandHandler : IRequestHandler<CreateSwitchCommand, Result<TransactionDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICrmReader _crmReader;
    private readonly IRegistryReader _registryReader;
    private readonly IIntegrationEventBus _eventBus;
    private readonly ILogger<CreateSwitchCommandHandler> _logger;

    public CreateSwitchCommandHandler(
        IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ICrmReader crmReader, IRegistryReader registryReader,
        IIntegrationEventBus eventBus, ILogger<CreateSwitchCommandHandler> logger)
    {
        _unitOfWork = unitOfWork; _mapper = mapper; _currentUser = currentUser;
        _authorizationService = authorizationService; _crmReader = crmReader;
        _registryReader = registryReader; _eventBus = eventBus; _logger = logger;
    }

    public async Task<Result<TransactionDto>> Handle(CreateSwitchCommand request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "transaction", "create", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null)
                return Result<TransactionDto>.Failure("Tenant context required.");

            var tenantId = _currentUser.TenantId.Value;

            if (!await _crmReader.IsInvestmentAccountKycApprovedAsync(request.InvestmentAccountId, tenantId, cancellationToken))
                return Result<TransactionDto>.Failure("Investment account KYC is not approved.");

            if (!await _registryReader.IsClassOpenForSubscriptionAsync(request.TargetClassId, tenantId, cancellationToken))
                return Result<TransactionDto>.Failure("Target fund class is not open for subscription.");

            var tx = TxEntity.CreateSwitch(tenantId, request.InvestmentAccountId, request.FundId, request.ClassId, request.TargetClassId, request.Amount, request.TradeDate);
            tx.CreatedBy = _currentUser.UserId;

            await _unitOfWork.Transactions.AddAsync(tx, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            await _eventBus.PublishAsync(new TransactionCreatedEvent(tx.Id, tenantId, tx.Type.ToString(), tx.InvestmentAccountId, tx.ClassId, tx.Amount), cancellationToken);

            _logger.LogInformation("Switch created: {TransactionId}", tx.Id);
            return Result<TransactionDto>.Success(_mapper.Map<TransactionDto>(tx));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating switch");
            return Result<TransactionDto>.Failure("An error occurred while creating the switch.");
        }
    }
}
