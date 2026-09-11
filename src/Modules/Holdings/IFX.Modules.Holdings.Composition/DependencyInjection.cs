using IFX.BuildingBlocks.Composition;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Modules.Holdings.Composition;

public static class DependencyInjection
{
    private static readonly HoldingsModuleInstaller _installer = new();

    public static IServiceCollection AddHoldingsModule(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.AddSingleton<IModuleInstaller>(_installer);
        _installer.InstallServices(services, configuration);
        return services;
    }
}
