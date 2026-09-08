using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Abac.Engine;
using IFX.BuildingBlocks.Application.Transactions;
using IFX.BuildingBlocks.Security.Authorization.Abac.Registry;
using IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;
using IFX.BuildingBlocks.Security.Authorization.Abstractions;
using IFX.Modules.Holdings.Application.Interfaces;
using IFX.Modules.Holdings.Application.Transactions;
using IFX.Modules.Holdings.Domain.Repositories;
using IFX.Modules.Holdings.Infrastructure.Authorization;
using IFX.Modules.Holdings.Infrastructure.Persistence;
using IFX.Modules.Holdings.Infrastructure.Repositories;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using IFX.Modules.Holdings.Application.Integrations;
using IFX.Modules.Holdings.Application.Ports;
using IFX.Modules.Holdings.Infrastructure.Messaging;
using IFX.Modules.Holdings.Infrastructure.Integrations;

namespace IFX.Modules.Holdings.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructureServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddMemoryCache();

        var connectionString = IFX.BuildingBlocks.EntityFrameworkCore.Configuration.RequiredConnectionString.Get(
            configuration,
            ModuleDatabase.ConnectionStringName);
        services.AddDbContext<HoldingsDbContext>(options =>
            options.UseSqlServer(connectionString, sql =>
            {
                sql.MigrationsAssembly(typeof(HoldingsDbContext).Assembly.FullName);
                sql.MigrationsHistoryTable(ModuleDatabase.HistoryTable, ModuleDatabase.Schema);
            }));

        services.AddScoped<IHoldingRepository, EfHoldingRepository>();
        services.AddScoped<IUnitOfWork, HoldingsUnitOfWork>();
        services.AddKeyedScoped<ITransactionExecutor, HoldingsTransactionExecutor>(typeof(HoldingsTransactionOwner));
        services.AddKeyedScoped<ITransactionParticipant, HoldingsInboxParticipant>(typeof(HoldingsTransactionOwner));
        services.AddScoped<IHoldingsInboxPort, HoldingsInboxPort>();
        services.AddScoped<IFX.Platform.Messaging.Runtime.IInboundIntegrationEventHandler, HoldingsInboundIntegrationEventHandler>();
        services.AddHttpContextAccessor();
        services.AddScoped<IResourceAuthorizationService, ResourceAuthorizationService>();

        services.AddSingleton<IAbacTemplateRegistry>(_ =>
        {
            var registry = new AbacTemplateRegistry();
            BuiltInTemplates.Register(registry);
            return registry;
        });
        services.AddScoped<IAbacPolicyEngine, AbacPolicyEngine>();
        services.AddSingleton<StaticAbacPolicyResolver>();
        services.AddScoped<IAbacPolicyResolver>(sp => sp.GetRequiredService<StaticAbacPolicyResolver>());
        services.AddScoped<IAbacPolicyCache, NoOpAbacPolicyCache>();

        return services;
    }
}
