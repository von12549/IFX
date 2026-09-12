using IFX.Platform.Authorization.Composition;
namespace IFX.ApiHost.Configuration;
public static class OpaConfiguration
{
    public static IServiceCollection AddOpaClient(this IServiceCollection services, IConfiguration configuration) => services.AddPlatformAuthorization(configuration);
}
