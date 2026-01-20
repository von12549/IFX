using AuthSamples.Platform.BackgroundJobs.Abstractions;
using AuthSamples.Platform.BackgroundJobs.Infrastructure.Hangfire;
using Hangfire;
using Hangfire.SqlServer;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace AuthSamples.Platform.BackgroundJobs.Composition;

/// <summary>
/// Extension methods for configuring background jobs services.
/// </summary>
public static class BackgroundJobsServiceCollectionExtensions
{
    /// <summary>
    /// Adds background jobs services to the service collection.
    /// </summary>
    /// <param name="services">The service collection.</param>
    /// <param name="configuration">The configuration.</param>
    /// <returns>The service collection for chaining.</returns>
    public static IServiceCollection AddBackgroundJobs(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var settings = configuration
            .GetSection(BackgroundJobsSettings.SectionName)
            .Get<BackgroundJobsSettings>() ?? new BackgroundJobsSettings();

        // Use default connection string if not specified in BackgroundJobs section
        if (string.IsNullOrEmpty(settings.ConnectionString))
        {
            settings.ConnectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException(
                    "BackgroundJobs:ConnectionString or ConnectionStrings:DefaultConnection must be configured.");
        }

        services.AddSingleton(settings);

        // Configure Hangfire
        services.AddHangfire(config => config
            .SetDataCompatibilityLevel(CompatibilityLevel.Version_180)
            .UseSimpleAssemblyNameTypeSerializer()
            .UseRecommendedSerializerSettings()
            .UseSqlServerStorage(settings.ConnectionString, new SqlServerStorageOptions
            {
                CommandBatchMaxTimeout = TimeSpan.FromMinutes(5),
                SlidingInvisibilityTimeout = TimeSpan.FromMinutes(5),
                QueuePollInterval = TimeSpan.Zero,
                UseRecommendedIsolationLevel = true,
                DisableGlobalLocks = true,
                SchemaName = "hangfire"
            }));

        // Add the Hangfire server
        services.AddHangfireServer(options =>
        {
            options.WorkerCount = settings.WorkerCount;
        });

        // Register our abstraction
        services.AddScoped<IBackgroundJobService, HangfireBackgroundJobService>();

        return services;
    }
}
