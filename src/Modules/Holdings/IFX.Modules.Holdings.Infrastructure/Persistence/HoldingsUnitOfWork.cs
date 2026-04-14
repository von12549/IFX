using IFX.Modules.Holdings.Application.Interfaces;
using IFX.Modules.Holdings.Domain.Repositories;
using Microsoft.EntityFrameworkCore.Storage;

namespace IFX.Modules.Holdings.Infrastructure.Persistence;

public class HoldingsUnitOfWork : IUnitOfWork
{
    private readonly HoldingsDbContext _context;
    private IDbContextTransaction? _transaction;

    public HoldingsUnitOfWork(HoldingsDbContext context, IHoldingRepository holdings)
    {
        _context = context;
        Holdings = holdings;
    }

    public IHoldingRepository Holdings { get; }

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
        => await _context.SaveChangesAsync(cancellationToken);

    public async Task BeginTransactionAsync(CancellationToken cancellationToken = default)
        => _transaction = await _context.Database.BeginTransactionAsync(cancellationToken);

    public async Task CommitTransactionAsync(CancellationToken cancellationToken = default)
    {
        if (_transaction != null) { await _transaction.CommitAsync(cancellationToken); await _transaction.DisposeAsync(); _transaction = null; }
    }

    public async Task RollbackTransactionAsync(CancellationToken cancellationToken = default)
    {
        if (_transaction != null) { await _transaction.RollbackAsync(cancellationToken); await _transaction.DisposeAsync(); _transaction = null; }
    }

    public void Dispose() { _transaction?.Dispose(); _context.Dispose(); }
}
