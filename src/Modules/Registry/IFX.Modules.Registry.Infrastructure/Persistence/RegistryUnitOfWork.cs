using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Domain.Repositories;
using Microsoft.EntityFrameworkCore.Storage;

namespace IFX.Modules.Registry.Infrastructure.Persistence;

public class RegistryUnitOfWork : IUnitOfWork
{
    private readonly RegistryDbContext _context;
    private IDbContextTransaction? _transaction;

    public RegistryUnitOfWork(
        RegistryDbContext context,
        IProductRepository products,
        IFundRepository funds,
        IFundClassRepository fundClasses)
    {
        _context = context;
        Products = products;
        Funds = funds;
        FundClasses = fundClasses;
    }

    public IProductRepository Products { get; }
    public IFundRepository Funds { get; }
    public IFundClassRepository FundClasses { get; }

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return await _context.SaveChangesAsync(cancellationToken);
    }

    public async Task BeginTransactionAsync(CancellationToken cancellationToken = default)
    {
        _transaction = await _context.Database.BeginTransactionAsync(cancellationToken);
    }

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
