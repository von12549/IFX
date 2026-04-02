using IFX.Modules.Holdings.Domain.Repositories;

namespace IFX.Modules.Holdings.Application.Interfaces;

public interface IUnitOfWork : IDisposable
{
    IHoldingRepository Holdings { get; }
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
    Task BeginTransactionAsync(CancellationToken cancellationToken = default);
    Task CommitTransactionAsync(CancellationToken cancellationToken = default);
    Task RollbackTransactionAsync(CancellationToken cancellationToken = default);
}
