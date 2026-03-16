using Amazon;
using Amazon.CognitoIdentityProvider;
using IFX.Modules.Auth.Application.Identity.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Modules.Auth.Infrastructure.IdentityProviders.Cognito;

public static class CognitoServiceCollectionExtensions
{
    public static IServiceCollection AddCognitoProvider(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // Configure options
        services.Configure<CognitoOptions>(
            configuration.GetSection(CognitoOptions.SectionName));

        services.Configure<CognitoOidcOptions>(
            configuration.GetSection(CognitoOidcOptions.SectionName));

        // Register AWS Cognito client
        var cognitoOptions = new CognitoOptions();
        configuration.GetSection(CognitoOptions.SectionName).Bind(cognitoOptions);

        services.AddSingleton<IAmazonCognitoIdentityProvider>(_ =>
        {
            var region = RegionEndpoint.GetBySystemName(cognitoOptions.Region ?? "us-east-1");
            return new AmazonCognitoIdentityProviderClient(region);
        });

        // Register HttpClient for Cognito OIDC
        services.AddHttpClient("CognitoOidc", client =>
        {
            client.DefaultRequestHeaders.Add("Accept", "application/json");
        });

        // Register provider implementations
        services.AddScoped<IIdentityProvider, CognitoIdentityProvider>();
        services.AddScoped<IOidcAuthService, CognitoOidcService>();

        return services;
    }
}
