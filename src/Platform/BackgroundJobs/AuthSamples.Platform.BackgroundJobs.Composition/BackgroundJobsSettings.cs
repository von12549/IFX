namespace AuthSamples.Platform.BackgroundJobs.Composition;

/// <summary>
/// Configuration settings for background jobs.
/// </summary>
public class BackgroundJobsSettings
{
    /// <summary>
    /// Configuration section name.
    /// </summary>
    public const string SectionName = "BackgroundJobs";

    /// <summary>
    /// SQL Server connection string for Hangfire storage.
    /// </summary>
    public string ConnectionString { get; set; } = string.Empty;

    /// <summary>
    /// Whether to enable the Hangfire dashboard.
    /// </summary>
    public bool EnableDashboard { get; set; } = true;

    /// <summary>
    /// The path for the Hangfire dashboard (default: /hangfire).
    /// </summary>
    public string DashboardPath { get; set; } = "/hangfire";

    /// <summary>
    /// Number of worker threads for processing jobs.
    /// </summary>
    public int WorkerCount { get; set; } = Environment.ProcessorCount * 2;
}
