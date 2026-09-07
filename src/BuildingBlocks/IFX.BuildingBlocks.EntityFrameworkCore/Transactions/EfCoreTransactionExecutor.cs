using System.Data;
using IFX.BuildingBlocks.Application.Transactions;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Logging;

namespace IFX.BuildingBlocks.EntityFrameworkCore.Transactions;

public abstract class EfCoreTransactionExecutor<TOwner, TDbContext>(
    TDbContext dbContext,
    ILogger logger) : ITransactionExecutor
    where TOwner : ITransactionOwner
    where TDbContext : DbContext
{
    private static readonly TimeSpan CleanupTimeout = TimeSpan.FromSeconds(5);
    private int _isExecuting;

    public Type OwnerType => typeof(TOwner);

    public async Task ExecutePersistenceAsync(
        Func<CancellationToken, Task> prepareAsync,
        CancellationToken cancellationToken)
    {
        var handlerState = CaptureTrackedState();
        try
        {
            await ExecuteWithStrategyAsync(async () =>
            {
                RestoreTrackedState(handlerState);
                await ExecuteOnceAsync(prepareAsync, cancellationToken, clearOnFailure: false);
            });
        }
        catch
        {
            ClearChanges();
            throw;
        }
    }

    public Task ExecuteAtomicAsync(
        Func<CancellationToken, Task> operationAsync,
        CancellationToken cancellationToken) =>
        ExecuteOnceAsync(operationAsync, cancellationToken, clearOnFailure: true);

    public ValueTask DiscardChangesAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        ClearChanges();
        return ValueTask.CompletedTask;
    }

    protected virtual Task ExecuteWithStrategyAsync(Func<Task> operationAsync) =>
        dbContext.Database.CreateExecutionStrategy().ExecuteAsync(operationAsync);

    protected virtual Task<IDbContextTransaction> BeginTransactionAsync(CancellationToken cancellationToken) =>
        dbContext.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted, cancellationToken);

    protected virtual async Task SaveChangesAsync(CancellationToken cancellationToken) =>
        await dbContext.SaveChangesAsync(cancellationToken);

    protected virtual void ClearChanges() => dbContext.ChangeTracker.Clear();

    private async Task ExecuteOnceAsync(
        Func<CancellationToken, Task> beforeSaveAsync,
        CancellationToken cancellationToken,
        bool clearOnFailure)
    {
        if (Interlocked.CompareExchange(ref _isExecuting, 1, 0) != 0)
        {
            throw new InvalidOperationException(
                $"Transaction executor '{GetType().Name}' does not support concurrent or nested execution.");
        }

        IDbContextTransaction? transaction = null;
        var commitAttempted = false;

        try
        {
            transaction = await BeginTransactionAsync(cancellationToken);
            await beforeSaveAsync(cancellationToken);
            await SaveChangesAsync(cancellationToken);
            commitAttempted = true;
            await transaction.CommitAsync(cancellationToken);
        }
        catch (Exception exception) when (commitAttempted)
        {
            throw new TransactionCommitOutcomeUnknownException(typeof(TOwner), exception);
        }
        catch (DbUpdateConcurrencyException exception)
        {
            await RollbackAsync(transaction);
            if (clearOnFailure)
            {
                ClearChanges();
            }

            throw new ConcurrencyConflictException(typeof(TOwner), exception);
        }
        catch (Exception)
        {
            await RollbackAsync(transaction);
            if (clearOnFailure)
            {
                ClearChanges();
            }

            throw;
        }
        finally
        {
            if (transaction is not null)
            {
                try
                {
                    await transaction.DisposeAsync();
                }
                catch (Exception disposeException)
                {
                    logger.LogWarning(
                        disposeException,
                        "Transaction dispose cleanup failed for transaction owner {TransactionOwner}",
                        typeof(TOwner).FullName);
                }
            }

            Volatile.Write(ref _isExecuting, 0);
        }
    }

    private IReadOnlyDictionary<object, EntityState> CaptureTrackedState() =>
        dbContext.ChangeTracker.Entries().ToDictionary(
            entry => entry.Entity,
            entry => entry.State,
            ReferenceEqualityComparer.Instance);

    private void RestoreTrackedState(IReadOnlyDictionary<object, EntityState> handlerState)
    {
        // A persistence retry must retain changes prepared by the Handler, without retaining a
        // pending record attached by the failed participant attempt.
        foreach (var entry in dbContext.ChangeTracker.Entries().ToArray())
        {
            if (handlerState.TryGetValue(entry.Entity, out var state))
            {
                entry.State = state;
            }
            else
            {
                entry.State = EntityState.Detached;
            }
        }
    }

    private async Task RollbackAsync(IDbContextTransaction? transaction)
    {
        if (transaction is null)
        {
            return;
        }

        using var cleanup = new CancellationTokenSource(CleanupTimeout);
        try
        {
            await transaction.RollbackAsync(cleanup.Token);
        }
        catch (Exception rollbackException)
        {
            logger.LogWarning(
                rollbackException,
                "Rollback cleanup failed for transaction owner {TransactionOwner}",
                typeof(TOwner).FullName);
        }
    }
}
