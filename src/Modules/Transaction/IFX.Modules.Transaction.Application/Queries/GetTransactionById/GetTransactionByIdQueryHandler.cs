using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Transaction.Application.Queries.GetTransactionById;

public class GetTransactionByIdQueryHandler : IRequestHandler<GetTransactionByIdQuery, Result<TransactionDto>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<GetTransactionByIdQueryHandler> _logger;

    public GetTransactionByIdQueryHandler(
        IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser,
        ILogger<GetTransactionByIdQueryHandler> logger)
    {
        _unitOfWork = unitOfWork; _mapper = mapper; _currentUser = currentUser; _logger = logger;
    }

    public async Task<Result<TransactionDto>> Handle(GetTransactionByIdQuery request, CancellationToken cancellationToken)
    {
        try
        {
            if (_currentUser.TenantId == null)
                return Result<TransactionDto>.Failure("Tenant context required.");

            var tx = await _unitOfWork.Transactions.GetByIdAsync(request.TransactionId, cancellationToken);
            if (tx == null || tx.TenantId != _currentUser.TenantId.Value)
                return Result<TransactionDto>.Failure("Transaction not found.");

            _logger.LogInformation("Retrieved transaction {TransactionId}", request.TransactionId);
            return Result<TransactionDto>.Success(_mapper.Map<TransactionDto>(tx));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving transaction {TransactionId}", request.TransactionId);
            return Result<TransactionDto>.Failure("An error occurred while retrieving the transaction.");
        }
    }
}
