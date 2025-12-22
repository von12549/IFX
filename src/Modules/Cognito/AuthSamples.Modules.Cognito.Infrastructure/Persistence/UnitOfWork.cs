using AuthSamples.Modules.Cognito.Application.Interfaces;
using AuthSamples.Modules.Cognito.Domain.Interfaces.Repositories;
using Microsoft.EntityFrameworkCore.Storage;

namespace AuthSamples.Modules.Cognito.Infrastructure.Persistence;

public class UnitOfWork : IUnitOfWork
{
    private readonly CognitoDbContext _context;
    private IDbContextTransaction? _transaction;

    public UnitOfWork(
        CognitoDbContext context,
        IUserRepository users,
        ILoginEventRepository loginEvents,
        ILogoutEventRepository logoutEvents,
        IRegistrationFlowEventRepository registrationFlowEvents,
        IUserActivityLogRepository userActivityLogs)
    {
        _context = context;
        Users = users;
        LoginEvents = loginEvents;
        LogoutEvents = logoutEvents;
        RegistrationFlowEvents = registrationFlowEvents;
        UserActivityLogs = userActivityLogs;
    }

    public IUserRepository Users { get; }
    public ILoginEventRepository LoginEvents { get; }
    public ILogoutEventRepository LogoutEvents { get; }
    public IRegistrationFlowEventRepository RegistrationFlowEvents { get; }
    public IUserActivityLogRepository UserActivityLogs { get; }

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
