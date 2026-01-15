using Amazon;
using Amazon.CognitoIdentityProvider;
using AuthSamples.Modules.Auth.Application.Interfaces;
using AuthSamples.Modules.Auth.Domain.Interfaces.Repositories;
using AuthSamples.Modules.Auth.Infrastructure.Configuration;
using AuthSamples.Modules.Auth.Infrastructure.Persistence;
using AuthSamples.Modules.Auth.Infrastructure.Persistence.Repositories;
using AuthSamples.Modules.Auth.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Caching.Memory;

namespace AuthSamples.Modules.Auth.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructureServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        // Configure CognitoSettings
        services.Configure<CognitoSettings>(options =>
            configuration.GetSection(CognitoSettings.SectionName).Bind(options));

        // Get settings for immediate use
        var cognitoSettings = new CognitoSettings();
        configuration.GetSection(CognitoSettings.SectionName).Bind(cognitoSettings);

        // Register AWS Cognito Client
        services.AddSingleton<IAmazonCognitoIdentityProvider>(sp =>
        {
            var region = RegionEndpoint.GetBySystemName(cognitoSettings?.Region ?? "us-east-1");
            return new AmazonCognitoIdentityProviderClient(region);
        });

        // Register Cognito Service (SDK-based - for backward compatibility)
        services.AddScoped<ICognitoService, CognitoService>();

        // Configure CognitoOidcSettings (OAuth/OIDC flow)
        services.Configure<CognitoOidcSettings>(options =>
            configuration.GetSection(CognitoOidcSettings.SectionName).Bind(options));

        // Register Memory Cache for OAuth state/PKCE storage
        services.AddMemoryCache();

        // Register HttpClient for OIDC service
        services.AddHttpClient("CognitoOidc", client =>
        {
            client.DefaultRequestHeaders.Add("Accept", "application/json");
        });

        // Register OIDC Auth Service (Managed Login flow)
        services.AddScoped<IOidcAuthService, CognitoOidcService>();

        // Register DbContext
        var connectionString = configuration.GetConnectionString("AuthDatabase");
        services.AddDbContext<AuthDbContext>(options =>
        {
            options.UseSqlServer(connectionString, sqlOptions =>
            {
                sqlOptions.MigrationsAssembly(typeof(AuthDbContext).Assembly.FullName);
                // Note: EnableRetryOnFailure is disabled because we use manual transaction management
                // via TransactionBehavior which wraps all commands in explicit transactions
            });
        });

        // Register Repositories
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IUserIdentityRepository, UserIdentityRepository>();
        services.AddScoped<IUserRoleRepository, UserRoleRepository>();
        services.AddScoped<ILoginEventRepository, LoginEventRepository>();
        services.AddScoped<ILogoutEventRepository, LogoutEventRepository>();
        services.AddScoped<IRegistrationFlowEventRepository, RegistrationFlowEventRepository>();
        services.AddScoped<IUserActivityLogRepository, UserActivityLogRepository>();
        services.AddScoped<IIdpRepository, IdpRepository>();

        // Register UnitOfWork
        services.AddScoped<IUnitOfWork, UnitOfWork>();

        return services;
    }
}
