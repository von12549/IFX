using IFX.Platform.Authorization.Contracts.V1;
using IFX.Platform.Authorization.Runtime;
using IFX.Platform.Authorization.Infrastructure.Opa;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace IFX.Platform.Authorization.Composition;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddPlatformAuthorization(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<OpaOptions>(configuration.GetSection("Opa"));
        services.AddHttpClient<IConditionEvaluationProvider, OpaEvaluationProvider>()
            .ConfigurePrimaryHttpMessageHandler(() => new HttpClientHandler { AllowAutoRedirect = false });
        services.TryAddScoped<IAuthorizationEvaluationContract, AuthorizationRuntime>();
        return services;
    }
}
