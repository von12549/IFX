using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Domain.Identity;
using IFX.Modules.Auth.Domain.Users;
using Microsoft.EntityFrameworkCore.Storage;

namespace IFX.Modules.Auth.Infrastructure.Persistence;

public class UnitOfWork : IUnitOfWork
{
    private readonly IfxDbContext _context;
    private IDbContextTransaction? _transaction;

    public UnitOfWork(
        IfxDbContext context,
        IUserRepository users,
        IUserIdentityRepository userIdentities,
        IRoleRepository roles,
        IPermissionRepository permissions,
        IRoleGroupRepository roleGroups,
        ITenantRepository tenants,
        IDepartmentRepository departments,
        ILoginEventRepository loginEvents,
        ILogoutEventRepository logoutEvents,
        IRegistrationFlowEventRepository registrationFlowEvents,
        IUserActivityLogRepository userActivityLogs,
        IIdpRepository idps,
        IEmailVerificationTokenRepository emailVerificationTokens,
        IPolicyDefinitionRepository policyDefinitions)
    {
        _context = context;
        Users = users;
        UserIdentities = userIdentities;
        Roles = roles;
        Permissions = permissions;
        RoleGroups = roleGroups;
        Tenants = tenants;
        Departments = departments;
        LoginEvents = loginEvents;
        LogoutEvents = logoutEvents;
        RegistrationFlowEvents = registrationFlowEvents;
        UserActivityLogs = userActivityLogs;
        Idps = idps;
        EmailVerificationTokens = emailVerificationTokens;
        PolicyDefinitions = policyDefinitions;
    }

    public IUserRepository Users { get; }
    public IUserIdentityRepository UserIdentities { get; }
    public IRoleRepository Roles { get; }
    public IPermissionRepository Permissions { get; }
    public IRoleGroupRepository RoleGroups { get; }
    public ITenantRepository Tenants { get; }
    public IDepartmentRepository Departments { get; }
    public ILoginEventRepository LoginEvents { get; }
    public ILogoutEventRepository LogoutEvents { get; }
    public IRegistrationFlowEventRepository RegistrationFlowEvents { get; }
    public IUserActivityLogRepository UserActivityLogs { get; }
    public IIdpRepository Idps { get; }
    public IEmailVerificationTokenRepository EmailVerificationTokens { get; }
    public IPolicyDefinitionRepository PolicyDefinitions { get; }

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
