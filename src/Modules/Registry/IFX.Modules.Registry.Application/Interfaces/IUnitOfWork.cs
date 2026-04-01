using IFX.Modules.Registry.Domain.Repositories;

namespace IFX.Modules.Registry.Application.Interfaces;

public interface IUnitOfWork : IDisposable
{
    IFundRepository Funds { get; }
    IFundClassRepository FundClasses { get; }
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
    Task BeginTransactionAsync(CancellationToken cancellationToken = default);
    Task CommitTransactionAsync(CancellationToken cancellationToken = default);
    Task RollbackTransactionAsync(CancellationToken cancellationToken = default);
}
