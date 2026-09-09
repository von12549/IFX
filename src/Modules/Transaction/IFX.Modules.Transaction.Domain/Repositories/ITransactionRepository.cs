using TxEntity = IFX.Modules.Transaction.Domain.Entities.Transaction;

namespace IFX.Modules.Transaction.Domain.Repositories;

public interface ITransactionRepository
{
    Task<TxEntity?> GetByIdAsync(Guid tenantId, Guid transactionId, CancellationToken ct = default);
    Task<IReadOnlyList<TxEntity>> GetByTenantAsync(Guid tenantId, CancellationToken ct = default);
    Task<IReadOnlyList<TxEntity>> GetByInvestmentAccountAsync(Guid tenantId, Guid investmentAccountId, CancellationToken ct = default);
    Task AddAsync(TxEntity transaction, CancellationToken ct = default);
    void Update(TxEntity transaction);
}
