using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Modules.Transaction.Domain.Repositories;
using Microsoft.EntityFrameworkCore.Storage;

namespace IFX.Modules.Transaction.Infrastructure.Persistence;

public class TransactionUnitOfWork : IUnitOfWork
{
    private readonly TransactionDbContext _context;
    private IDbContextTransaction? _transaction;

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

    public async Task BeginTransactionAsync(CancellationToken cancellationToken = default)
        => _transaction = await _context.Database.BeginTransactionAsync(cancellationToken);

    public async Task CommitTransactionAsync(CancellationToken cancellationToken = default)
    {
        if (_transaction != null)
        {
            await _transaction.CommitAsync(cancellationToken);
            await _transaction.DisposeAsync();
            _transaction = null;
        }
    }

    public async Task RollbackTransactionAsync(CancellationToken cancellationToken = default)
    {
        if (_transaction != null)
        {
            await _transaction.RollbackAsync(cancellationToken);
            await _transaction.DisposeAsync();
            _transaction = null;
        }
    }

    public void Dispose()
    {
        _transaction?.Dispose();
        _context.Dispose();
    }
}
