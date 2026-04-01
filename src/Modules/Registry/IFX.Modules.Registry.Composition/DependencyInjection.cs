using App.Abstractions;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Modules.Registry.Composition;

/// <summary>
/// Extension methods for registering the Registry module.
/// </summary>
public static class DependencyInjection
{
    private static readonly RegistryModuleInstaller _installer = new();

    /// <summary>
    /// Registers all Registry module services and the module installer.
    /// </summary>
    public static IServiceCollection AddRegistryModule(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // Register the module installer for discovery
        services.AddSingleton<IModuleInstaller>(_installer);

        // Install module services
        _installer.InstallServices(services, configuration);

        return services;
    }

    /// <summary>
    /// Maps all Registry module endpoints (10 total: 5 Fund, 5 FundClass).
    /// Note: Prefer using IModuleInstaller.MapEndpoints() via the discovery pattern.
    /// </summary>
    public static IEndpointRouteBuilder MapRegistryModuleEndpoints(this IEndpointRouteBuilder builder)
    {
        return _installer.MapEndpoints(builder);
    }
}
