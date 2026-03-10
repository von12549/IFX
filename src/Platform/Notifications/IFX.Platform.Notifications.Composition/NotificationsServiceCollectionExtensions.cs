using IFX.Platform.Notifications.Abstractions;
using IFX.Platform.Notifications.Infrastructure.SendGrid;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SendGrid;

namespace IFX.Platform.Notifications.Composition;

/// <summary>
/// Extension methods for configuring notification services.
/// </summary>
public static class NotificationsServiceCollectionExtensions
{
    /// <summary>
    /// Adds notification services to the service collection.
    /// </summary>
    /// <param name="services">The service collection.</param>
    /// <param name="configuration">The configuration.</param>
    /// <returns>The service collection for chaining.</returns>
    public static IServiceCollection AddNotifications(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var settings = configuration
            .GetSection(SendGridSettings.SectionName)
            .Get<SendGridSettings>() ?? new SendGridSettings();

        if (string.IsNullOrEmpty(settings.ApiKey))
        {
            throw new InvalidOperationException(
                $"{SendGridSettings.SectionName}:ApiKey must be configured.");
        }

        if (string.IsNullOrEmpty(settings.DefaultFromEmail))
        {
            throw new InvalidOperationException(
                $"{SendGridSettings.SectionName}:DefaultFromEmail must be configured.");
        }

        services.AddSingleton(settings);

        // Register SendGrid client
        services.AddSingleton<ISendGridClient>(_ => new SendGridClient(settings.ApiKey));

        // Register our abstraction
        services.AddScoped<IEmailService, SendGridEmailService>();

        return services;
    }

    /// <summary>
    /// Adds notification services with optional configuration (for environments where email is not needed).
    /// </summary>
    /// <param name="services">The service collection.</param>
    /// <param name="configuration">The configuration.</param>
    /// <returns>The service collection for chaining.</returns>
    public static IServiceCollection AddNotificationsOptional(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        var settings = configuration
            .GetSection(SendGridSettings.SectionName)
            .Get<SendGridSettings>();

        if (settings == null || string.IsNullOrEmpty(settings.ApiKey))
        {
            // Register a no-op implementation for development/testing
            services.AddScoped<IEmailService, NoOpEmailService>();
            return services;
        }

        return services.AddNotifications(configuration);
    }
}
