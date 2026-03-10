using IFX.Modules.Auth.Application.Interfaces;
using IFX.Platform.BackgroundJobs.Abstractions;
using Microsoft.Extensions.DependencyInjection;
using Serilog;

namespace IFX.Modules.Auth.Composition;

public static class RecurringJobsExtensions
{
    /// <summary>
    /// Registers recurring jobs for the Auth module.
    /// Should be called after the application is built and background jobs are configured.
    /// </summary>
    public static void RegisterAuthRecurringJobs(this IServiceProvider serviceProvider)
    {
        var backgroundJobService = serviceProvider.GetService<IBackgroundJobService>();

        if (backgroundJobService == null)
        {
            Log.Warning("[Auth] Background job service not available. Skipping recurring job registration.");
            return;
        }

        // Register email verification token cleanup job
        // Runs daily at 2:00 AM
        backgroundJobService.AddOrUpdateRecurring<IEmailVerificationCleanupService>(
            "email-verification-cleanup",
            service => service.CleanupExpiredTokensAsync(default),
            "0 2 * * *"); // Cron: At 02:00 every day

        Log.Information("[Auth] Registered recurring job: email-verification-cleanup (daily at 2:00 AM)");
    }
}
