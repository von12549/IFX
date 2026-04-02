using IFX.Modules.Transaction.Domain.Repositories;
using IFX.Modules.Transaction.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using TxEntity = IFX.Modules.Transaction.Domain.Entities.Transaction;

namespace IFX.Modules.Transaction.Infrastructure.Repositories;

public class EfTransactionRepository : ITransactionRepository
{
    private readonly TransactionDbContext _context;

    public EfTransactionRepository(TransactionDbContext context) => _context = context;

    public async Task<TxEntity?> GetByIdAsync(Guid transactionId, CancellationToken ct = default)
        => await _context.Transactions.FirstOrDefaultAsync(t => t.Id == transactionId, ct);

    public async Task<IReadOnlyList<TxEntity>> GetByTenantAsync(Guid tenantId, CancellationToken ct = default)
        => await _context.Transactions.Where(t => t.TenantId == tenantId).ToListAsync(ct);

    public async Task<IReadOnlyList<TxEntity>> GetByInvestorAsync(Guid tenantId, Guid investorId, CancellationToken ct = default)
        => await _context.Transactions.Where(t => t.TenantId == tenantId && t.InvestorId == investorId).ToListAsync(ct);

    public async Task AddAsync(TxEntity transaction, CancellationToken ct = default)
        => await _context.Transactions.AddAsync(transaction, ct);

    public void Update(TxEntity transaction)
        => _context.Transactions.Update(transaction);
}
