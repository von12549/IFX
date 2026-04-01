using IFX.Modules.CRM.Domain.Repositories;

namespace IFX.Modules.CRM.Application.Interfaces;

public interface IUnitOfWork : IDisposable
{
    IPartyRepository Parties { get; }
    IInvestorRepository Investors { get; }
    IPartyInvestorRepository PartyInvestors { get; }
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
    Task BeginTransactionAsync(CancellationToken cancellationToken = default);
    Task CommitTransactionAsync(CancellationToken cancellationToken = default);
    Task RollbackTransactionAsync(CancellationToken cancellationToken = default);
}
