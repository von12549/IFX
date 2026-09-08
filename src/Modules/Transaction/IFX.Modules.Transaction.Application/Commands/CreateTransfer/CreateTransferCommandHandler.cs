using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.Common.Authorization;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Modules.Transaction.Application.Ports;
using MediatR;
using Microsoft.Extensions.Logging;
using TxEntity = IFX.Modules.Transaction.Domain.Entities.Transaction;
using IFX.BuildingBlocks.Application.Events;

namespace IFX.Modules.Transaction.Application.Commands.CreateTransfer;
public class CreateTransferCommandHandler : IRequestHandler<CreateTransferCommand, Result<TransactionDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly IAccountCompliancePort _accountCompliance;
    private readonly IClassSubscriptionAvailabilityPort _classSubscriptionAvailability;
    private readonly ICommittedEventBuffer _eventBuffer;
    private readonly ILogger<CreateTransferCommandHandler> _logger;
    public CreateTransferCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, IAccountCompliancePort accountCompliance, IClassSubscriptionAvailabilityPort classSubscriptionAvailability, ICommittedEventBuffer eventBuffer, ILogger<CreateTransferCommandHandler> logger)
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

    public async Task<Result<TransactionDto>> Handle(CreateTransferCommand request, CancellationToken cancellationToken)
    {
        {
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("transaction", "create", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            if (_currentUser.TenantId == null)
                return Result<TransactionDto>.Failure("Tenant context required.");
            var tenantId = _currentUser.TenantId.Value;
            if (!await _accountCompliance.IsApprovedAsync(request.InvestmentAccountId, tenantId, cancellationToken))
                return Result<TransactionDto>.Failure("Investment account KYC is not approved.");
            if (!await _classSubscriptionAvailability.IsOpenAsync(request.TargetClassId, tenantId, cancellationToken))
                return Result<TransactionDto>.Failure("Target fund class is not open for subscription.");
            var tx = TxEntity.CreateTransfer(tenantId, request.InvestmentAccountId, request.FundId, request.ClassId, request.TargetClassId, request.Amount, request.TradeDate);
            tx.CreatedBy = _currentUser.UserId;
            await _unitOfWork.Transactions.AddAsync(tx, cancellationToken);
            _logger.LogInformation("Transfer created: {TransactionId}", tx.Id);
            return Result<TransactionDto>.Success(_mapper.Map<TransactionDto>(tx));
        }
    }
}
