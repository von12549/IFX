using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Transaction.Abstractions.Events;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.Common.Authorization;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Platform.Messaging.Abstractions;
using MediatR;
using Microsoft.Extensions.Logging;
using IFX.BuildingBlocks.Application.Events;

namespace IFX.Modules.Transaction.Application.Commands.CancelTransaction;
public class CancelTransactionCommandHandler : IRequestHandler<CancelTransactionCommand, Result<TransactionDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICommittedEventBuffer _eventBuffer;
    private readonly ILogger<CancelTransactionCommandHandler> _logger;
    public CancelTransactionCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ICommittedEventBuffer eventBuffer, ILogger<CancelTransactionCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBuffer = eventBuffer;
        _logger = logger;
    }

    public async Task<Result<TransactionDto>> Handle(CancelTransactionCommand request, CancellationToken cancellationToken)
    {
        try
        {
            if (_currentUser.TenantId == null)
                return Result<TransactionDto>.Failure("Tenant context required.");
            var tx = await _unitOfWork.Transactions.GetByIdAsync(request.TransactionId, cancellationToken);
            if (tx == null || tx.TenantId != _currentUser.TenantId.Value)
                return Result<TransactionDto>.Failure("Transaction not found.");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("transaction", "cancel", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            tx.Cancel(request.Reason);
            _unitOfWork.Transactions.Update(tx);
            _eventBuffer.Add(new TransactionCancelledEvent(tx.Id, tx.TenantId));
            _logger.LogInformation("Transaction cancelled: {TransactionId}", tx.Id);
            return Result<TransactionDto>.Success(_mapper.Map<TransactionDto>(tx));
        }
        catch (IFX.BuildingBlocks.Domain.DomainRuleViolationException ex)
        {
            return Result<TransactionDto>.Failure(ex.Message);
        }
    }
}
