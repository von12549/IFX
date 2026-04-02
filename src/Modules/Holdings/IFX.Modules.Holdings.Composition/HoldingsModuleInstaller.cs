using App.Abstractions;
using IFX.Modules.Holdings.Application;
using IFX.Modules.Holdings.Application.EventHandlers;
using IFX.Modules.Holdings.Infrastructure;
using IFX.Modules.Holdings.Infrastructure.Persistence;
using IFX.Modules.Holdings.Presentation.Extensions;
using IFX.Modules.Registry.Abstractions.Events;
using IFX.Modules.Transaction.Abstractions.Events;
using IFX.Platform.Messaging.Composition;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Serilog;

namespace IFX.Modules.Holdings.Composition;

public sealed class HoldingsModuleInstaller : IModuleInstaller
{
    public string ModuleName => "Holdings";

    public IServiceCollection InstallServices(IServiceCollection services, IConfiguration configuration)
    {
        Log.Information("[{Module}] Registering module services...", ModuleName);

        services.AddApplicationServices();
        services.AddInfrastructureServices(configuration);
        services.AddScoped<IAppMigrator, HoldingsMigrator>();

        // Register integration event handlers
        services.AddIntegrationEventHandler<TransactionProcessedEvent, TransactionProcessedEventHandler>();
        services.AddIntegrationEventHandler<ClassStatusChangedEvent, ClassStatusChangedEventHandler>();

        Log.Information("[{Module}] Module services registered successfully", ModuleName);
        return services;
    }

    public IEndpointRouteBuilder MapEndpoints(IEndpointRouteBuilder builder)
    {
        Log.Information("[{Module}] Mapping module endpoints...", ModuleName);
        builder.MapHoldingEndpoints();
        Log.Information("[{Module}] Module endpoints mapped: 4 total", ModuleName);
        return builder;
    }
}
