using Amazon;
using Amazon.CognitoIdentityProvider;
using IFX.Modules.Auth.Application.Identity.Interfaces;
using IFX.Modules.Auth.Application.Interfaces;
using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Domain.Identity;
using IFX.Modules.Auth.Domain.Users;
using IFX.Modules.Auth.Infrastructure.Authorization.Repositories;
using IFX.Modules.Auth.Infrastructure.Identity.Configuration;
using IFX.Modules.Auth.Infrastructure.Identity.Repositories;
using IFX.Modules.Auth.Infrastructure.Identity.Services;
using IFX.Modules.Auth.Infrastructure.Persistence;
using IFX.Modules.Auth.Infrastructure.Users.Repositories;
using IFX.Modules.Auth.Infrastructure.Users.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Caching.Memory;

namespace IFX.Modules.Auth.Infrastructure;

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

        // Register HttpClient for OIDC services
        services.AddHttpClient("CognitoOidc", client =>
        {
            client.DefaultRequestHeaders.Add("Accept", "application/json");
        });

        services.AddHttpClient("OidcDiscovery", client =>
        {
            client.DefaultRequestHeaders.Add("Accept", "application/json");
            client.Timeout = TimeSpan.FromSeconds(30);
        });

        // Register OIDC Auth Service (Managed Login flow)
        services.AddScoped<IOidcAuthService, CognitoOidcService>();

        // Register OIDC Discovery Service (for fetching well-known configuration)
        services.AddScoped<IOidcDiscoveryService, OidcDiscoveryService>();

        // Register Email Verification Service
        services.AddScoped<IEmailVerificationService, EmailVerificationService>();
        services.AddScoped<IEmailVerificationCleanupService, EmailVerificationCleanupService>();

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
        services.AddScoped<IEmailVerificationTokenRepository, EmailVerificationTokenRepository>();

        // Register UnitOfWork
        services.AddScoped<IUnitOfWork, UnitOfWork>();

        return services;
    }
}
