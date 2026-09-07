using App.Abstractions;
using IFX.Modules.Registry.Application;
using IFX.Modules.Registry.Infrastructure;
using IFX.Modules.Registry.Infrastructure.Persistence;
using IFX.Modules.Registry.Presentation.Extensions;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Serilog;

namespace IFX.Modules.Registry.Composition;

/// <summary>
/// Registry module installer — registers all Registry module services and endpoints.
/// </summary>
public sealed class RegistryModuleInstaller : IModuleInstaller
{
    public string ModuleName => "Registry";

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

        builder.MapProductEndpoints();    // 6 endpoints: products (GET/GET-by-id/GET-funds/POST/PUT/DELETE)
        builder.MapFundEndpoints();       // 5 endpoints: funds (GET/GET-by-id/POST/PUT/DELETE)
        builder.MapFundClassEndpoints();  // 5 endpoints: fund classes (GET/GET-by-id/POST/PUT/DELETE)

        Log.Information("[{Module}] Module endpoints mapped: 16 total (6 Product, 5 Fund, 5 FundClass)", ModuleName);
        return builder;
    }
}
