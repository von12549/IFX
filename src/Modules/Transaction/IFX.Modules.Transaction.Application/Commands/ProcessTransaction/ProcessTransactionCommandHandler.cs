using IFX.Modules.Transaction.Application.Ports.Authorization;
using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.Transaction.Contracts.V1.Events;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.Common.Authorization;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;
using IFX.BuildingBlocks.Application.Events;

namespace IFX.Modules.Transaction.Application.Commands.ProcessTransaction;
public class ProcessTransactionCommandHandler : IRequestHandler<ProcessTransactionCommand, Result<TransactionDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly IResourceAuthorizationService _authorizationService;
    private readonly ICommittedEventBuffer _eventBuffer;
    private readonly ILogger<ProcessTransactionCommandHandler> _logger;
    public ProcessTransactionCommandHandler(IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser, IResourceAuthorizationService authorizationService, ICommittedEventBuffer eventBuffer, ILogger<ProcessTransactionCommandHandler> logger)
    {
        _unitOfWork = unitOfWork;
        _mapper = mapper;
        _currentUser = currentUser;
        _authorizationService = authorizationService;
        _eventBuffer = eventBuffer;
        _logger = logger;
    }

    public async Task<Result<TransactionDto>> Handle(ProcessTransactionCommand request, CancellationToken cancellationToken)
    {
        try
        {
            if (_currentUser.TenantId == null)
                return Result<TransactionDto>.Failure("Tenant context required.");
            var tx = await _unitOfWork.Transactions.GetByIdAsync(_currentUser.TenantId.Value, request.TransactionId, cancellationToken);
            if (tx == null || tx.TenantId != _currentUser.TenantId.Value)
                return Result<TransactionDto>.Failure("Transaction not found.");
            await _authorizationService.AuthorizeWithResolvedPolicyAsync("transaction", "process", new TenantScopeResourceAttributes(_currentUser.TenantId), ct: cancellationToken);
            tx.Process(request.NAVPrice);
            _unitOfWork.Transactions.Update(tx);
            // Publish event — Holdings module will update balances
            _eventBuffer.Add(new TransactionProcessedV1(tx.Id, tx.Type.ToString(), tx.InvestmentAccountId, tx.ClassId, tx.TargetClassId, tx.Units!.Value, tx.NAVPrice!.Value));
            _logger.LogInformation("Transaction processed: {TransactionId} Units={Units} NAV={NAVPrice}", tx.Id, tx.Units, tx.NAVPrice);
            return Result<TransactionDto>.Success(_mapper.Map<TransactionDto>(tx));
        }
        catch (IFX.BuildingBlocks.Domain.DomainRuleViolationException)
        {
            return Result<TransactionDto>.Failure("The requested state transition is not allowed.");
        }
    }
}
