using IFX.Modules.Transaction.Abstractions.DTOs;

namespace IFX.Modules.Transaction.Abstractions.Interfaces;

public interface ITransactionReader
{
    Task<TransactionSummaryDto?> GetTransactionByIdAsync(Guid transactionId, CancellationToken ct = default);
    Task<OrderSummaryDto?> GetOrderByIdAsync(Guid orderId, CancellationToken ct = default);
    Task<IReadOnlyList<OrderSummaryDto>> GetOrdersByInvestmentAccountAsync(Guid tenantId, Guid investmentAccountId, CancellationToken ct = default);
}
