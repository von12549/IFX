using IFX.Modules.Transaction.Abstractions.DTOs;

namespace IFX.Modules.Transaction.Abstractions.Interfaces;

public interface ITransactionReader
{
    Task<TransactionSummaryDto?> GetTransactionByIdAsync(Guid transactionId, CancellationToken ct = default);
}
