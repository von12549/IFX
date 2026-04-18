using IFX.Modules.Transaction.Domain.Repositories;
namespace IFX.Modules.Transaction.Application.Interfaces;
public interface IUnitOfWork : IDisposable
{
    ITransactionRepository Transactions { get; }
    IOrderRepository Orders { get; }
    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
    Task BeginTransactionAsync(CancellationToken cancellationToken = default);
    Task CommitTransactionAsync(CancellationToken cancellationToken = default);
    Task RollbackTransactionAsync(CancellationToken cancellationToken = default);
}
