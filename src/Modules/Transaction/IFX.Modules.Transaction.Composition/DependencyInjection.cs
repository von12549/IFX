using App.Abstractions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Modules.Transaction.Composition;

public static class DependencyInjection
{
    private static readonly TransactionModuleInstaller _installer = new();

    public static IServiceCollection AddTransactionModule(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddSingleton<IModuleInstaller>(_installer);
        _installer.InstallServices(services, configuration);
        return services;
    }
}
