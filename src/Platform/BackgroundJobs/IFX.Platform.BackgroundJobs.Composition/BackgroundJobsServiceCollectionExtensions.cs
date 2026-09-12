using IFX.Platform.BackgroundJobs.Contracts;
using IFX.Platform.BackgroundJobs.Infrastructure.Hangfire;
using IFX.Platform.Shared.Constants;
using Hangfire;
using Hangfire.SqlServer;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Platform.BackgroundJobs.Composition;

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
    public static IServiceCollection AddBackgroundJobsClient(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var settings = configuration
            .GetSection(BackgroundJobsSettings.SectionName)
            .Get<BackgroundJobsSettings>() ?? new BackgroundJobsSettings();

        // Check if background jobs are disabled (for testing)
        if (!settings.Enabled)
        {
            services.AddSingleton(settings);
            services.AddScoped<IBackgroundJobService, NoOpBackgroundJobService>();
            return services;
        }

        // Use default connection string if not specified in BackgroundJobs section
        if (string.IsNullOrEmpty(settings.ConnectionString))
        {
            settings.ConnectionString = configuration.GetConnectionString("BackgroundJobsDatabase")
                ?? configuration.GetConnectionString("DefaultConnection")
                ?? configuration.GetConnectionString("AuthDatabase")
                ?? throw new InvalidOperationException(
                    "BackgroundJobs:ConnectionString or ConnectionStrings:BackgroundJobsDatabase must be configured.");
        }

        services.AddSingleton(settings);

        // Configure Hangfire
        services.AddHangfire((provider, config) => config
            .SetDataCompatibilityLevel(CompatibilityLevel.Version_180)
            .UseSimpleAssemblyNameTypeSerializer()
            .UseTypeResolver(new BackgroundJobTypeResolver(provider.GetServices<BackgroundJobTypeAlias>()).Resolve)
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

        // Server execution is registered separately by the worker/all runtime role.
        services.AddScoped<IBackgroundJobService, HangfireBackgroundJobService>();

        return services;
    }

    /// <summary>
    /// Adds Hangfire Server execution for worker-capable runtime roles.
    /// The client must be registered first.
    /// </summary>
    public static IServiceCollection AddBackgroundJobsServer(
        this IServiceCollection services,
        IConfiguration configuration,
        string? runtimeInstanceIdentity = null)
    {
        var settings = configuration
            .GetSection(BackgroundJobsSettings.SectionName)
            .Get<BackgroundJobsSettings>() ?? new BackgroundJobsSettings();

        if (!settings.Enabled)
        {
            return services;
        }

        services.AddHangfireServer(options =>
        {
            options.WorkerCount = settings.WorkerCount;
            options.Queues = settings.Queues.Length > 0
                ? settings.Queues
                : QueueNames.DefaultQueues;

            if (!string.IsNullOrEmpty(runtimeInstanceIdentity))
            {
                options.ServerName = runtimeInstanceIdentity;
            }
            else if (!string.IsNullOrEmpty(settings.ServerName))
            {
                options.ServerName = settings.ServerName;
            }
        });

        return services;
    }

    /// <summary>
    /// Compatibility helper for local callers that intentionally use all-in-one mode.
    /// </summary>
    public static IServiceCollection AddBackgroundJobs(
        this IServiceCollection services,
        IConfiguration configuration) =>
        services.AddBackgroundJobsClient(configuration).AddBackgroundJobsServer(configuration);
}
