using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.Common.Authorization;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Modules.Transaction.Application.Ports;
using MediatR;
using Microsoft.Extensions.Logging;
using TxEntity = IFX.Modules.Transaction.Domain.Entities.Transaction;
using IFX.BuildingBlocks.Application.Events;

namespace IFX.Modules.Transaction.Application.Commands.CreateSubscription;
public class CreateSubscriptionCommandHandler : IRequestHandler<CreateSubscriptionCommand, Result<TransactionDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly IAccountCompliancePort _accountCompliance;
    private readonly IClassSubscriptionAvailabilityPort _classSubscriptionAvailability;
    private readonly ICommittedEventBuffer _eventBuffer;
    private readonly ILogger<CreateSubscriptionCommandHandler> _logger;
    public CreateSubscriptionCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, IAccountCompliancePort accountCompliance, IClassSubscriptionAvailabilityPort classSubscriptionAvailability, ICommittedEventBuffer eventBuffer, ILogger<CreateSubscriptionCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _accountCompliance = accountCompliance;
        _classSubscriptionAvailability = classSubscriptionAvailability;
        _eventBuffer = eventBuffer;
        _logger = logger;
    }

    public async Task<Result<TransactionDto>> Handle(CreateSubscriptionCommand request, CancellationToken cancellationToken)
    {
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("transaction", "create", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            if (_currentUser.TenantId == null)
                return Result<TransactionDto>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;
            // Cross-module validation
            if (!await _accountCompliance.IsApprovedAsync(request.InvestmentAccountId, tenantId, cancellationToken))
                return Result<TransactionDto>.Failure("Investment account KYC is not approved.");
            if (!await _classSubscriptionAvailability.IsOpenAsync(request.ClassId, tenantId, cancellationToken))
                return Result<TransactionDto>.Failure("Fund class is not open for subscription.");
            var tx = TxEntity.CreateSubscription(tenantId, request.InvestmentAccountId, request.FundId, request.ClassId, request.Amount, request.TradeDate);
            tx.CreatedBy = _currentUser.UserId;
            await _unitOfWork.Transactions.AddAsync(tx, cancellationToken);
            _logger.LogInformation("Subscription created: {TransactionId}", tx.Id);
            return Result<TransactionDto>.Success(_mapper.Map<TransactionDto>(tx));
        }
    }
}
