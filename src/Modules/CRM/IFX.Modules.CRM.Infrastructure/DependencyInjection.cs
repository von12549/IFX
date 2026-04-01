using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Abac.Engine;
using IFX.BuildingBlocks.Security.Authorization.Abac.Registry;
using IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.CRM.Abstractions.Interfaces;
using IFX.Modules.CRM.Application.Interfaces;
using IFX.Modules.CRM.Domain.Repositories;
using IFX.Modules.CRM.Infrastructure.Authorization;
using IFX.Modules.CRM.Infrastructure.Persistence;
using IFX.Modules.CRM.Infrastructure.Repositories;
using IFX.Modules.CRM.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Modules.CRM.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructureServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // Register Memory Cache
        services.AddMemoryCache();

        // Register DbContext
        var connectionString = configuration.GetConnectionString("CrmDatabase")
            ?? configuration.GetConnectionString("DefaultConnection");
        services.AddDbContext<CrmDbContext>(options =>
        {
            options.UseSqlServer(connectionString, sqlOptions =>
            {
                sqlOptions.MigrationsAssembly(typeof(CrmDbContext).Assembly.FullName);
            });
        });

        // Register Repositories
        services.AddScoped<IPartyRepository, EfPartyRepository>();
        services.AddScoped<IInvestorRepository, EfInvestorRepository>();
        services.AddScoped<IPartyInvestorRepository, EfPartyInvestorRepository>();

        // Register UnitOfWork
        services.AddScoped<IUnitOfWork, CrmUnitOfWork>();

        // Register CrmReader (cross-module read service)
        services.AddScoped<ICrmReader, CrmReader>();

        // Register shared authorization services
        services.AddHttpContextAccessor();
        services.AddScoped<IResourceAuthorizationService, ResourceAuthorizationService>();

        // Register ABAC template engine (singleton — thread-safe, no per-request state)
        services.AddSingleton<IAbacTemplateRegistry>(_ =>
        {
            var registry = new AbacTemplateRegistry();
            BuiltInTemplates.Register(registry);
            return registry;
        });
        services.AddScoped<IAbacPolicyEngine, AbacPolicyEngine>();

        // Register ABAC policy resolver: static fallback resolver.
        // CRM resource policies are seeded into the shared PolicyDefinition table (Auth module's DB)
        // and resolved via Auth module's DbAbacPolicyResolver which is registered in the shared DI container.
        // The StaticAbacPolicyResolver here acts as a deny-by-default fallback.
        services.AddSingleton<StaticAbacPolicyResolver>();
        services.AddScoped<IAbacPolicyResolver>(sp => sp.GetRequiredService<StaticAbacPolicyResolver>());
        // IAbacPolicyCache: CRM does not own PolicyDefinitions; use a no-op adapter.
        services.AddScoped<IAbacPolicyCache, NoOpAbacPolicyCache>();

        return services;
    }
}
