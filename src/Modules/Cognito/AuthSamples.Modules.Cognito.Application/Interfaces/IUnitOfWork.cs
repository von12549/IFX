using AuthSamples.Modules.Cognito.Domain.Interfaces.Repositories;

namespace AuthSamples.Modules.Cognito.Application.Interfaces;

public interface IUnitOfWork : IDisposable
{
    IUserRepository Users { get; }
    IUserRoleRepository UserRoles { get; }
    ILoginEventRepository LoginEvents { get; }
    ILogoutEventRepository LogoutEvents { get; }
    IRegistrationFlowEventRepository RegistrationFlowEvents { get; }
    IUserActivityLogRepository UserActivityLogs { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
    Task BeginTransactionAsync(CancellationToken cancellationToken = default);
    Task CommitTransactionAsync(CancellationToken cancellationToken = default);
    Task RollbackTransactionAsync(CancellationToken cancellationToken = default);
}
