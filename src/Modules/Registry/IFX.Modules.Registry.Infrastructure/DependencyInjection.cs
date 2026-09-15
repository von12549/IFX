using IFX.Modules.Registry.Application.Ports.Authorization;
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
using Microsoft.Extensions.DependencyInjection.Extensions;
using IFX.Platform.Context.Runtime.Inbound;
using IFX.Platform.Context.Runtime.Outbound;
using IFX.Modules.IAM.Client.Authorization;
using IFX.Modules.Registry.Infrastructure.Messaging;
using IFX.Modules.Registry.Infrastructure.Integrations.Outbound.IAM;
using IFX.Modules.Registry.Infrastructure.Integrations.Outbound.Persistence;

namespace IFX.Modules.Registry.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructureServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.TryAddScoped<InboundContractContextValidator>();
        services.TryAddSingleton<ProviderExecutionContextFactory>();
        services.TryAddScoped<OutboundContractRequestContextFactory>();
        services.TryAddScoped<IamResourceAuthorizationClient>();
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

        services.AddScoped<IClassSubscriptionDataPort, ClassSubscriptionDataAdapter>();

        // Note: ICurrentUser, IPermissionChecker, IResourceAuthorizationService and IAbacPolicyResolver
        // are registered by the IAM module and shared
        // via the common DI container. Registry handlers resolve them from there.

        services.AddScoped<IResourceAuthorizationService, ResourceAuthorizationAdapter>();
        return services;
    }
}
