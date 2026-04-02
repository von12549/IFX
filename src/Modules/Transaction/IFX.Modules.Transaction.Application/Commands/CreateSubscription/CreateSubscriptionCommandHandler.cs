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

namespace IFX.Modules.Transaction.Application.Commands.CreateSubscription;

public class CreateSubscriptionCommandHandler : IRequestHandler<CreateSubscriptionCommand, Result<TransactionDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICrmReader _crmReader;
    private readonly IRegistryReader _registryReader;
    private readonly IIntegrationEventBus _eventBus;
    private readonly ILogger<CreateSubscriptionCommandHandler> _logger;

    public CreateSubscriptionCommandHandler(
        IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser,
        IResourceAuthorizationService authorizationService,
        ICrmReader crmReader, IRegistryReader registryReader,
        IIntegrationEventBus eventBus, ILogger<CreateSubscriptionCommandHandler> logger)
    {
        _unitOfWork = unitOfWork; _mapper = mapper; _currentUser = currentUser;
        _authorizationService = authorizationService; _crmReader = crmReader;
        _registryReader = registryReader; _eventBus = eventBus; _logger = logger;
    }

    public async Task<Result<TransactionDto>> Handle(CreateSubscriptionCommand request, CancellationToken cancellationToken)
    {
        try
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync(
                "transaction", "create", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);

            if (_currentUser.TenantId == null)
                return Result<TransactionDto>.Failure("Tenant context required.");

            var tenantId = _currentUser.TenantId.Value;

            // Cross-module validation
            if (!await _crmReader.IsInvestorKycApprovedAsync(request.InvestorId, tenantId, cancellationToken))
                return Result<TransactionDto>.Failure("Investor KYC is not approved.");

            if (!await _registryReader.IsClassOpenForSubscriptionAsync(request.ClassId, tenantId, cancellationToken))
                return Result<TransactionDto>.Failure("Fund class is not open for subscription.");

            if (!await _crmReader.PartyExistsAsync(request.PartyId, tenantId, cancellationToken))
                return Result<TransactionDto>.Failure("Party not found.");

            var tx = TxEntity.CreateSubscription(tenantId, request.PartyId, request.InvestorId, request.FundId, request.ClassId, request.Amount, request.TradeDate);
            tx.CreatedBy = _currentUser.UserId;

            await _unitOfWork.Transactions.AddAsync(tx, cancellationToken);
            await _unitOfWork.SaveChangesAsync(cancellationToken);

            await _eventBus.PublishAsync(new TransactionCreatedEvent(tx.Id, tenantId, tx.Type.ToString(), tx.InvestorId, tx.ClassId, tx.Amount), cancellationToken);

            _logger.LogInformation("Subscription created: {TransactionId}", tx.Id);
            return Result<TransactionDto>.Success(_mapper.Map<TransactionDto>(tx));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating subscription");
            return Result<TransactionDto>.Failure("An error occurred while creating the subscription.");
        }
    }
}
