using Amazon;
using Amazon.CognitoIdentityProvider;
using IFX.Platform.Authentication.Contracts.V1;
using IFX.Platform.Authentication.Infrastructure.Cognito;
using IFX.Platform.Authentication.Infrastructure.Auth0;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Platform.Authentication.Composition;

public static class ProviderRegistration
{
    public static IServiceCollection AddExternalIdentityProvider(this IServiceCollection services, IConfiguration configuration, string provider)
    {
        services.AddPlatformAuthentication();
        switch (provider.ToLowerInvariant())
        {
            case "cognito":
                services.Configure<CognitoOptions>(configuration.GetSection(CognitoOptions.SectionName));
                services.AddSingleton<IAmazonCognitoIdentityProvider>(_ => new AmazonCognitoIdentityProviderClient(
                    RegionEndpoint.GetBySystemName(configuration["CognitoSettings:Region"] ?? "us-east-1")));
                services.AddScoped<CognitoIdentityProvider>();
                services.AddScoped<IExternalAccountContract>(p => p.GetRequiredService<CognitoIdentityProvider>());
                services.AddScoped<ICredentialAuthenticationContract>(p => p.GetRequiredService<CognitoIdentityProvider>());
                services.AddScoped<ITokenLifecycleContract>(p => p.GetRequiredService<CognitoIdentityProvider>());
                break;
            case "auth0":
                services.Configure<Auth0Options>(configuration.GetSection(Auth0Options.SectionName));
                services.AddScoped<Auth0IdentityProvider>();
                services.AddScoped<IExternalAccountContract>(p => p.GetRequiredService<Auth0IdentityProvider>());
                services.AddScoped<ICredentialAuthenticationContract>(p => p.GetRequiredService<Auth0IdentityProvider>());
                services.AddScoped<ITokenLifecycleContract>(p => p.GetRequiredService<Auth0IdentityProvider>());
                break;
            default: throw new InvalidOperationException("Unknown external identity provider.");
        }
        return services;
    }
}
