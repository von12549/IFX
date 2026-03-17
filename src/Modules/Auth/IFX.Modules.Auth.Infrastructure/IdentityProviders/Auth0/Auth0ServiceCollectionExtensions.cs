using IFX.Modules.Auth.Application.Identity.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Modules.Auth.Infrastructure.IdentityProviders.Auth0;

public static class Auth0ServiceCollectionExtensions
{
    public static IServiceCollection AddAuth0Provider(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.Configure<Auth0Options>(
            configuration.GetSection(Auth0Options.SectionName));

        services.AddHttpClient("Auth0Oidc", client =>
        {
            client.DefaultRequestHeaders.Add("Accept", "application/json");
        });

        services.AddScoped<IIdentityProvider, Auth0IdentityProvider>();
        services.AddScoped<IOidcAuthService, Auth0OidcService>();

        return services;
    }
}
