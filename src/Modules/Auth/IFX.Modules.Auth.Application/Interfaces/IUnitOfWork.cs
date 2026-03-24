using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Domain.Identity;
using IFX.Modules.Auth.Domain.Users;


namespace IFX.Modules.Auth.Application.Interfaces;

public interface IUnitOfWork : IDisposable
{
    IUserRepository Users { get; }
    IUserIdentityRepository UserIdentities { get; }
    IRoleRepository Roles { get; }
    IPermissionRepository Permissions { get; }
    IRoleGroupRepository RoleGroups { get; }
    ITenantRepository Tenants { get; }
    IDepartmentRepository Departments { get; }
    ILoginEventRepository LoginEvents { get; }
    ILogoutEventRepository LogoutEvents { get; }
    IRegistrationFlowEventRepository RegistrationFlowEvents { get; }
    IUserActivityLogRepository UserActivityLogs { get; }
    IIdpRepository Idps { get; }
    IEmailVerificationTokenRepository EmailVerificationTokens { get; }
    IPolicyDefinitionRepository PolicyDefinitions { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
    Task BeginTransactionAsync(CancellationToken cancellationToken = default);
    Task CommitTransactionAsync(CancellationToken cancellationToken = default);
    Task RollbackTransactionAsync(CancellationToken cancellationToken = default);
}
