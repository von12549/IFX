using Hangfire;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;

namespace AuthSamples.Platform.BackgroundJobs.Composition;

/// <summary>
/// Extension methods for configuring background jobs middleware.
/// </summary>
public static class BackgroundJobsApplicationBuilderExtensions
{
    /// <summary>
    /// Adds the Hangfire dashboard to the application pipeline.
    /// </summary>
    /// <param name="app">The application builder.</param>
    /// <returns>The application builder for chaining.</returns>
    public static IApplicationBuilder UseBackgroundJobsDashboard(this IApplicationBuilder app)
    {
        var settings = app.ApplicationServices.GetRequiredService<BackgroundJobsSettings>();

        // Only enable dashboard if background jobs are enabled and dashboard is enabled
        if (settings.Enabled && settings.EnableDashboard)
        {
            app.UseHangfireDashboard(settings.DashboardPath, new DashboardOptions
            {
                // In production, you should add authorization
                // Authorization = new[] { new HangfireAuthorizationFilter() }
            });
        }

        return app;
    }
}
