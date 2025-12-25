using Amazon;
using Amazon.CognitoIdentityProvider;
using AuthSamples.Modules.Cognito.Application.Interfaces;
using AuthSamples.Modules.Cognito.Domain.Interfaces.Repositories;
using AuthSamples.Modules.Cognito.Infrastructure.Configuration;
using AuthSamples.Modules.Cognito.Infrastructure.Persistence;
using AuthSamples.Modules.Cognito.Infrastructure.Persistence.Repositories;
using AuthSamples.Modules.Cognito.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace AuthSamples.Modules.Cognito.Infrastructure;

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

        // Register Cognito Service
        services.AddScoped<ICognitoService, CognitoService>();

        // Register DbContext
        var connectionString = configuration.GetConnectionString("CognitoDatabase");
        services.AddDbContext<CognitoDbContext>(options =>
        {
            options.UseSqlServer(connectionString, sqlOptions =>
            {
                sqlOptions.MigrationsAssembly(typeof(CognitoDbContext).Assembly.FullName);
                // Note: EnableRetryOnFailure is disabled because we use manual transaction management
                // via TransactionBehavior which wraps all commands in explicit transactions
            });
        });

        // Register Repositories
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<ILoginEventRepository, LoginEventRepository>();
        services.AddScoped<ILogoutEventRepository, LogoutEventRepository>();
        services.AddScoped<IRegistrationFlowEventRepository, RegistrationFlowEventRepository>();
        services.AddScoped<IUserActivityLogRepository, UserActivityLogRepository>();

        // Register UnitOfWork
        services.AddScoped<IUnitOfWork, UnitOfWork>();

        return services;
    }
}
