using IFX.BuildingBlocks.Composition;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Modules.CRM.Composition;

/// <summary>
/// Extension methods for registering the CRM module.
/// </summary>
public static class DependencyInjection
{
    private static readonly CrmModuleInstaller _installer = new();

    /// <summary>
    /// Registers all CRM module services and the module installer.
    /// </summary>
    public static IServiceCollection AddCrmModule(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // Register the module installer for discovery
        services.AddSingleton<IModuleInstaller>(_installer);

        // Install module services
        _installer.InstallServices(services, configuration);

        return services;
    }
}
