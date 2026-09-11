using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Abac.Engine;
using IFX.BuildingBlocks.Application.Transactions;
using IFX.BuildingBlocks.Security.Authorization.Abac.Registry;
using IFX.BuildingBlocks.Security.Authorization.Abac.Resolver;
using IFX.Modules.Transaction.Application.Interfaces;
using IFX.Modules.Transaction.Application.Transactions;
using IFX.Modules.Transaction.Domain.Repositories;
using IFX.Modules.Transaction.Infrastructure.Repositories;
using IFX.Modules.Transaction.Infrastructure.Authorization;
using IFX.Modules.Transaction.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using IFX.Modules.Transaction.Infrastructure.Messaging;

namespace IFX.Modules.Transaction.Infrastructure;

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
        services.AddDbContext<TransactionDbContext>(options =>
            options.UseSqlServer(connectionString, sql =>
            {
                sql.MigrationsAssembly(typeof(TransactionDbContext).Assembly.FullName);
                sql.MigrationsHistoryTable(ModuleDatabase.HistoryTable, ModuleDatabase.Schema);
            }));

        services.AddScoped<ITransactionRepository, EfTransactionRepository>();
        services.AddScoped<IOrderRepository, EfOrderRepository>();
        services.AddScoped<IUnitOfWork, TransactionUnitOfWork>();
        services.AddKeyedScoped<ITransactionExecutor, TransactionModuleExecutor>(typeof(TransactionModuleOwner));
        services.AddKeyedScoped<ITransactionParticipant, TransactionOutboxParticipant>(typeof(TransactionModuleOwner));
        services.AddScoped<IFX.Platform.Messaging.Runtime.IModuleOutboxStore, TransactionOutboxStore>();

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
