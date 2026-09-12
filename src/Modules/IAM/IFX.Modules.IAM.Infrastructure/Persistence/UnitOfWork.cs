using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Modules.IAM.Domain.Identity;
using IFX.Modules.IAM.Domain.Users;

namespace IFX.Modules.IAM.Infrastructure.Persistence;

public class UnitOfWork : IUnitOfWork
{
    private readonly IfxDbContext _context;

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
        IPolicyDefinitionRepository policyDefinitions,
        IGlobalRoleRepository globalRoles)
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
        GlobalRoles = globalRoles;
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
    public IGlobalRoleRepository GlobalRoles { get; }

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return await _context.SaveChangesAsync(cancellationToken);
    }

    public void Dispose()
    {
        _context.Dispose();
    }
}
