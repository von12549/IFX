using App.Abstractions;
using IFX.Modules.Transaction.Application;
using IFX.Modules.Transaction.Infrastructure;
using IFX.Modules.Transaction.Infrastructure.Persistence;
using IFX.Modules.Transaction.Presentation.Extensions;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Serilog;

namespace IFX.Modules.Transaction.Composition;

public sealed class TransactionModuleInstaller : IModuleInstaller
{
    public string ModuleName => "Transaction";

    public IServiceCollection InstallServices(IServiceCollection services, IConfiguration configuration)
    {
        Log.Information("[{Module}] Registering module services...", ModuleName);
        services.AddApplicationServices();
        services.AddInfrastructureServices(configuration);
        Log.Information("[{Module}] Module services registered successfully", ModuleName);
        return services;
    }

    public IEndpointRouteBuilder MapEndpoints(IEndpointRouteBuilder builder)
    {
        Log.Information("[{Module}] Mapping module endpoints...", ModuleName);
        builder.MapTransactionEndpoints();
        Log.Information("[{Module}] Module endpoints mapped: 8 total", ModuleName);
        return builder;
    }
}
