using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Modules.IAM.Domain.Identity;
using IFX.Modules.IAM.Domain.Users;


namespace IFX.Modules.IAM.Application.Interfaces;

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
    IGlobalRoleRepository GlobalRoles { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);
}
