using IFX.Modules.IAM.Application.Ports.Authorization;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.Modules.IAM.Application.Access;
using IFX.Modules.IAM.Infrastructure.Integrations.Outbound.Authorization;
using IFX.Modules.IAM.Infrastructure.Integrations.Inbound;
using IFX.BuildingBlocks.Application.Transactions;
using IFX.BuildingBlocks.Application.Context;
using IFX.Modules.IAM.Application.Access.Abac.Registry;
using IFX.Modules.IAM.Application.Access.Abac.Resolver;
using IFX.Modules.IAM.Application.Identity.Interfaces;
using IFX.Modules.IAM.Application.Identity.Ports;
using IFX.Modules.IAM.Application.Interfaces;
using IFX.Modules.IAM.Application.Transactions;
using IFX.Modules.IAM.Domain.Access;
using IFX.Modules.IAM.Domain.Tenancy;
using IFX.Modules.IAM.Domain.Identity;
using IFX.Modules.IAM.Domain.Users;
using IFX.Modules.IAM.Infrastructure.Access;
using IFX.Modules.IAM.Infrastructure.Access.Repositories;
using IFX.Modules.IAM.Infrastructure.Tenancy.Repositories;
using IFX.Modules.IAM.Infrastructure.Identity.Repositories;
using IFX.Modules.IAM.Infrastructure.Integrations.Outbound.Authentication;
using IFX.Modules.IAM.Application.Identity.Services;
using IFX.Modules.IAM.Infrastructure.Persistence;
using IFX.Modules.IAM.Infrastructure.Users.Repositories;
using IFX.Modules.IAM.Infrastructure.Users.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using IFX.Platform.Context.Runtime.Inbound;

namespace IFX.Modules.IAM.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructureServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.TryAddScoped<InboundContractContextValidator>();
        services.TryAddSingleton<ProviderExecutionContextFactory>();
        // Register Memory Cache (shared by all providers for OIDC state/PKCE)
        services.AddMemoryCache();

        services.AddScoped<ProviderServicesAdapter>();
        services.AddScoped<IExternalAccountService>(p => p.GetRequiredService<ProviderServicesAdapter>());
        services.AddScoped<ICredentialAuthenticationService>(p => p.GetRequiredService<ProviderServicesAdapter>());
        services.AddScoped<ITokenLifecycleService>(p => p.GetRequiredService<ProviderServicesAdapter>());
        services.AddScoped<OidcProtocolAdapter>();
        services.AddScoped<IOidcProtocolService>(p => p.GetRequiredService<OidcProtocolAdapter>());
        services.AddScoped<IOidcDiscoveryService>(p => p.GetRequiredService<OidcProtocolAdapter>());
        services.AddScoped<IOidcUserInfoClient>(p => p.GetRequiredService<OidcProtocolAdapter>());
        services.AddScoped<IOidcClientConfigurationSource, OidcClientConfigurationSource>();
        services.AddScoped<IOidcAuthService, OidcAuthenticationService>();
        services.AddScoped<IEmailVerificationService, EmailVerificationService>();
        services.AddScoped<IEmailVerificationCleanupService, EmailVerificationCleanupService>();

        // Register DbContext
        var connectionString = IFX.BuildingBlocks.EntityFrameworkCore.Configuration.RequiredConnectionString.Get(
            configuration,
            ModuleDatabase.ConnectionStringName);
        services.AddDbContext<IfxDbContext>(options =>
        {
            options.UseSqlServer(connectionString, sqlOptions =>
            {
                sqlOptions.MigrationsAssembly(typeof(IfxDbContext).Assembly.FullName);
                sqlOptions.MigrationsHistoryTable(ModuleDatabase.HistoryTable, ModuleDatabase.Schema);
                // Note: EnableRetryOnFailure is disabled because we use manual transaction management
                // via TransactionBehavior which wraps all commands in explicit transactions
            });
        });

        // Register Repositories
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IUserIdentityRepository, UserIdentityRepository>();
        services.AddScoped<IRoleRepository, RoleRepository>();
        services.AddScoped<IPermissionRepository, PermissionRepository>();
        services.AddScoped<IRoleGroupRepository, RoleGroupRepository>();
        services.AddScoped<ITenantRepository, TenantRepository>();
        services.AddScoped<IDepartmentRepository, DepartmentRepository>();
        services.AddScoped<ILoginEventRepository, LoginEventRepository>();
        services.AddScoped<ILogoutEventRepository, LogoutEventRepository>();
        services.AddScoped<IRegistrationFlowEventRepository, RegistrationFlowEventRepository>();
        services.AddScoped<IUserActivityLogRepository, UserActivityLogRepository>();
        services.AddScoped<IIdpRepository, IdpRepository>();
        services.AddScoped<IEmailVerificationTokenRepository, EmailVerificationTokenRepository>();
        services.AddScoped<IPolicyDefinitionRepository, PolicyDefinitionRepository>();
        services.AddScoped<IGlobalRoleRepository, GlobalRoleRepository>();

        // Register UnitOfWork
        services.AddScoped<IUnitOfWork, UnitOfWork>();
        services.AddKeyedScoped<ITransactionExecutor, IamTransactionExecutor>(typeof(IamTransactionOwner));

        // Register shared authorization services
        services.AddHttpContextAccessor();
        services.AddScoped<HttpIdentityFacts>();
        services.AddScoped<VerifiedIdentityFacts>();
        services.AddScoped<IExecutionIdentityFacts>(services => services.GetRequiredService<VerifiedIdentityFacts>());
        services.AddScoped<ExecutionTenantSelection>();
        services.AddScoped<ICurrentUser, CurrentUser>();
        services.AddScoped<IPermissionChecker, PermissionChecker>();
        services.AddScoped<ResourceAuthorizationService>();
        services.AddScoped<IResourceAuthorizationService>(p => p.GetRequiredService<ResourceAuthorizationService>());
        services.AddScoped<IFX.Modules.IAM.Contracts.V1.Authorization.IResourceAuthorizationContract, ResourceAuthorizationInboundAdapter>();
        services.AddScoped<IPolicyEvaluationPort, PolicyEvaluationAdapter>();
        services.AddScoped<IAuthorizationEnvironmentPort, AuthorizationEnvironment>();

        // Register ABAC template engine (singleton — thread-safe, no per-request state)
        services.AddSingleton<IAbacTemplateRegistry>(_ =>
        {
            var registry = new AbacTemplateRegistry();
            BuiltInTemplates.Register(registry);
            return registry;
        });


        // Register ABAC policy resolver: DB-backed, with empty static fallback as last resort
        services.AddSingleton<StaticAbacPolicyResolver>();
        // Policies are read on each decision; there is no cross-request policy cache.
        // Register as scoped and expose via both interfaces.
        services.AddScoped<DbAbacPolicyResolver>();
        services.AddScoped<IAbacPolicyResolver>(sp => sp.GetRequiredService<DbAbacPolicyResolver>());

        return services;
    }
}
