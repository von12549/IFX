using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Domain.Repositories;
using Microsoft.EntityFrameworkCore.Storage;

namespace IFX.Modules.CRM.Infrastructure.Persistence;

public class CrmUnitOfWork : IUnitOfWork
{
    private readonly CrmDbContext _context;
    private IDbContextTransaction? _transaction;

    public CrmUnitOfWork(
        CrmDbContext context,
        IPartyRepository parties,
        IInvestorRepository investors,
        IPartyInvestorRepository partyInvestors)
    {
        _context = context;
        Parties = parties;
        Investors = investors;
        PartyInvestors = partyInvestors;
    }

    public IPartyRepository Parties { get; }
    public IInvestorRepository Investors { get; }
    public IPartyInvestorRepository PartyInvestors { get; }

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
