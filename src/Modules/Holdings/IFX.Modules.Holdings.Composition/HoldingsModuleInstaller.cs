using IFX.BuildingBlocks.Composition;
using IFX.Modules.Holdings.Application;
using IFX.Modules.Holdings.Infrastructure;
using IFX.Modules.Holdings.Infrastructure.Persistence;
using IFX.Modules.Holdings.Presentation.Extensions;
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
