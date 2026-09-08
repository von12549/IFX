using IFX.Modules.Registry.Application.Interfaces;
using IFX.Modules.Registry.Application.Ports;
using IFX.BuildingBlocks.Application.Transactions;
using IFX.Modules.Registry.Application.Transactions;
using IFX.Modules.Registry.Domain.Repositories;
using IFX.Modules.Registry.Infrastructure.Persistence;
using IFX.Modules.Registry.Infrastructure.Repositories;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using IFX.Modules.Registry.Infrastructure.Messaging;

namespace IFX.Modules.Registry.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructureServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // Register DbContext
        var connectionString = IFX.BuildingBlocks.EntityFrameworkCore.Configuration.RequiredConnectionString.Get(
            configuration,
            ModuleDatabase.ConnectionStringName);

        services.AddDbContext<RegistryDbContext>(options =>
        {
            options.UseSqlServer(connectionString, sqlOptions =>
            {
                sqlOptions.MigrationsAssembly(typeof(RegistryDbContext).Assembly.FullName);
                sqlOptions.MigrationsHistoryTable(ModuleDatabase.HistoryTable, ModuleDatabase.Schema);
            });
        });

        // Register Repositories
        services.AddScoped<IProductRepository, EfProductRepository>();
        services.AddScoped<IFundRepository, EfFundRepository>();
        services.AddScoped<IFundClassRepository, EfFundClassRepository>();

        // Register UnitOfWork
        services.AddScoped<IUnitOfWork, RegistryUnitOfWork>();
        services.AddKeyedScoped<ITransactionExecutor, RegistryTransactionExecutor>(typeof(RegistryTransactionOwner));
        services.AddKeyedScoped<ITransactionParticipant, RegistryOutboxParticipant>(typeof(RegistryTransactionOwner));
        services.AddScoped<IFX.Platform.Messaging.Runtime.IModuleOutboxStore, RegistryOutboxStore>();

        services.AddScoped<IClassSubscriptionDataPort, Integrations.ClassSubscriptionDataAdapter>();

        // Note: ICurrentUser, IPermissionChecker, IResourceAuthorizationService and IAbacPolicyResolver
        // are registered by the Auth module and shared
        // via the common DI container. Registry handlers resolve them from there.

        return services;
    }
}
