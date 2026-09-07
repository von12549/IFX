using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Modules.Transaction.Domain.Repositories;

namespace IFX.Modules.Transaction.Infrastructure.Persistence;

public class TransactionUnitOfWork : IUnitOfWork
{
    private readonly TransactionDbContext _context;

    public TransactionUnitOfWork(
        TransactionDbContext context,
        ITransactionRepository transactions,
        IOrderRepository orders)
    {
        _context = context;
        Transactions = transactions;
        Orders = orders;
    }

    public ITransactionRepository Transactions { get; }
    public IOrderRepository Orders { get; }

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
        => await _context.SaveChangesAsync(cancellationToken);

    public void Dispose()
    {
        _context.Dispose();
    }
}
