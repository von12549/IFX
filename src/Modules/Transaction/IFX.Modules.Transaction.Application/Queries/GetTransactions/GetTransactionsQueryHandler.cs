using AutoMapper;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Transaction.Application.Common;
using IFX.Modules.Transaction.Application.DTOs;
using IFX.Modules.Transaction.Application.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace IFX.Modules.Transaction.Application.Queries.GetTransactions;

public class GetTransactionsQueryHandler : IRequestHandler<GetTransactionsQuery, Result<IReadOnlyList<TransactionDto>>>
{
    private readonly IUnitOfWork _unitOfWork;
    private readonly IMapper _mapper;
    private readonly ICurrentUser _currentUser;
    private readonly ILogger<GetTransactionsQueryHandler> _logger;

    public GetTransactionsQueryHandler(
        IUnitOfWork unitOfWork, IMapper mapper, ICurrentUser currentUser,
        ILogger<GetTransactionsQueryHandler> logger)
    {
        _unitOfWork = unitOfWork; _mapper = mapper; _currentUser = currentUser; _logger = logger;
    }

    public async Task<Result<IReadOnlyList<TransactionDto>>> Handle(GetTransactionsQuery request, CancellationToken cancellationToken)
    {
        try
        {
            if (_currentUser.TenantId == null)
                return Result<IReadOnlyList<TransactionDto>>.Failure("Tenant context required.");

            var transactions = await _unitOfWork.Transactions.GetByTenantAsync(_currentUser.TenantId.Value, cancellationToken);
            var dtos = transactions.Select(t => _mapper.Map<TransactionDto>(t)).ToList();

            _logger.LogInformation("Retrieved {Count} transactions for tenant {TenantId}", dtos.Count, _currentUser.TenantId);
            return Result<IReadOnlyList<TransactionDto>>.Success(dtos);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving transactions");
            return Result<IReadOnlyList<TransactionDto>>.Failure("An error occurred while retrieving transactions.");
        }
    }
}
