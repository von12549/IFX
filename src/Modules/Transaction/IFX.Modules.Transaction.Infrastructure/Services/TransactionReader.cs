using IFX.Modules.Transaction.Abstractions.DTOs;
using IFX.Modules.Transaction.Abstractions.Interfaces;
using IFX.Modules.Transaction.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace IFX.Modules.Transaction.Infrastructure.Services;

public class TransactionReader : ITransactionReader
{
    private readonly TransactionDbContext _context;

    public TransactionReader(TransactionDbContext context) => _context = context;

    public async Task<TransactionSummaryDto?> GetTransactionByIdAsync(Guid transactionId, CancellationToken ct = default)
    {
        var tx = await _context.Transactions.FirstOrDefaultAsync(t => t.Id == transactionId, ct);
        if (tx == null) return null;
        return new TransactionSummaryDto(tx.Id, tx.TenantId, tx.Type.ToString(), tx.InvestmentAccountId, tx.ClassId, tx.Amount, tx.Status.ToString());
    }
}
