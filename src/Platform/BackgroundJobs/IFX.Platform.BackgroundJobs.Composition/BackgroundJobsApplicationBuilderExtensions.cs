using Hangfire;
using Hangfire.Dashboard;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Platform.BackgroundJobs.Composition;

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
                Authorization = new[] { new AllowAllDashboardAuthorizationFilter() }
            });
        }

        return app;
    }
}

/// <summary>
/// Authorization filter that allows all requests to the Hangfire dashboard.
/// WARNING: Only use in development. In production, implement proper authorization.
/// </summary>
public class AllowAllDashboardAuthorizationFilter : IDashboardAuthorizationFilter
{
    public bool Authorize(DashboardContext context)
    {
        // Allow all requests - no authentication required
        return true;
    }
}
