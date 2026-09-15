using IFX.Modules.Holdings.Application.Ports.Authorization;
using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Application.Transactions;
using IFX.Modules.Holdings.Application.Interfaces;
using IFX.Modules.Holdings.Application.Transactions;
using IFX.Modules.Holdings.Domain.Repositories;
using IFX.Modules.Holdings.Infrastructure.Persistence;
using IFX.Modules.Holdings.Infrastructure.Repositories;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using IFX.Modules.Holdings.Application.Integrations;
using IFX.Modules.Holdings.Application.Ports;
using IFX.Modules.Holdings.Infrastructure.Messaging;
using IFX.Modules.Holdings.Infrastructure.Integrations.Inbound;
using IFX.Modules.Holdings.Infrastructure.Integrations.Outbound.IAM;

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
        services.AddScoped<IFX.Platform.Messaging.Runtime.IModuleInboxDiagnosticStore, HoldingsInboxDiagnosticStore>();
        services.AddScoped<IFX.Platform.Messaging.Runtime.IInboundIntegrationEventHandler, HoldingsInboundIntegrationEventHandler>();
        services.AddHttpContextAccessor();
        services.AddScoped<IResourceAuthorizationService, ResourceAuthorizationAdapter>();
        return services;
    }
}
