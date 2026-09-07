using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Abac.Engine;
using IFX.BuildingBlocks.Application.Transactions;
using IFX.BuildingBlocks.Security.Authorization.Abac.Registry;
using IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Auth.Application.Identity.Interfaces;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Application.Transactions;
using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Domain.Identity;
using IFX.Modules.Auth.Domain.Users;
using IFX.Modules.Auth.Infrastructure.Authorization;
using IFX.Modules.Auth.Infrastructure.Authorization.Repositories;
using IFX.Modules.Auth.Infrastructure.Identity.Repositories;
using IFX.Modules.Auth.Infrastructure.Identity.Services;
using IFX.Modules.Auth.Infrastructure.Persistence;
using IFX.Modules.Auth.Infrastructure.Users.Repositories;
using IFX.Modules.Auth.Infrastructure.Users.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Modules.Auth.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructureServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // Register Memory Cache (shared by all providers for OIDC state/PKCE)
        services.AddMemoryCache();

        // Register HttpClient for OIDC Discovery (provider-neutral)
        services.AddHttpClient("OidcDiscovery", client =>
        {
            client.DefaultRequestHeaders.Add("Accept", "application/json");
            client.Timeout = TimeSpan.FromSeconds(30);
        });

        // Register shared OIDC services
        services.AddScoped<IOidcDiscoveryService, OidcDiscoveryService>();
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
        services.AddKeyedScoped<ITransactionExecutor, AuthTransactionExecutor>(typeof(AuthTransactionOwner));

        // Register shared authorization services
        services.AddHttpContextAccessor();
        services.AddScoped<ICurrentUser, CurrentUser>();
        services.AddScoped<IPermissionChecker, PermissionChecker>();
        services.AddScoped<IResourceAuthorizationService, ResourceAuthorizationService>();

        // Register ABAC template engine (singleton — thread-safe, no per-request state)
        services.AddSingleton<IAbacTemplateRegistry>(_ =>
        {
            var registry = new AbacTemplateRegistry();
            BuiltInTemplates.Register(registry);
            return registry;
        });
        services.AddScoped<IAbacPolicyEngine, AbacPolicyEngine>();

        // Register ABAC policy resolver: DB-backed, with empty static fallback as last resort
        services.AddSingleton<StaticAbacPolicyResolver>();
        // DbAbacPolicyResolver implements both IAbacPolicyResolver and IAbacPolicyCache.
        // Register as scoped and expose via both interfaces.
        services.AddScoped<DbAbacPolicyResolver>();
        services.AddScoped<IAbacPolicyResolver>(sp => sp.GetRequiredService<DbAbacPolicyResolver>());
        services.AddScoped<IAbacPolicyCache>(sp => sp.GetRequiredService<DbAbacPolicyResolver>());

        return services;
    }
}
