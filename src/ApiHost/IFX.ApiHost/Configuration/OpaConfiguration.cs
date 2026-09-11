using IFX.BuildingBlocks.Security.Authorization;
using IFX.BuildingBlocks.Security.Authorization.Opa;
using Microsoft.Extensions.Options;

namespace IFX.ApiHost.Configuration;

public static class OpaConfiguration
{
    public static IServiceCollection AddOpaClient(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<OpaOptions>(configuration.GetSection(OpaOptions.SectionName));

        var opaEnabled = configuration.GetValue<bool?>($"{OpaOptions.SectionName}:Enabled") ?? true;

        if (opaEnabled)
        {
            services.AddHttpClient<OpaClient>((sp, client) =>
            {
                var options = sp.GetRequiredService<IOptions<OpaOptions>>().Value;
                client.BaseAddress = new Uri(options.BaseUrl);
                client.Timeout = TimeSpan.FromSeconds(options.TimeoutSeconds);
            });
            services.AddSingleton<IOpaPolicyClient, OpaClient>();
        }
        else
        {
            services.AddSingleton<IOpaPolicyClient, NullOpaPolicyClient>();
        }

        return services;
    }
}
