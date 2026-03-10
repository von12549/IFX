namespace IFX.Platform.Shared.Constants;

/// <summary>
/// Standard queue names for background job processing.
/// </summary>
public static class QueueNames
{
    /// <summary>
    /// Default queue for general-purpose jobs.
    /// </summary>
    public const string Default = "default";

    /// <summary>
    /// Queue for email-related jobs.
    /// </summary>
    public const string Email = "email";

    /// <summary>
    /// Queue for report generation jobs.
    /// </summary>
    public const string Report = "report";

    /// <summary>
    /// Gets the default set of queues for processing.
    /// </summary>
    public static string[] DefaultQueues => [Default, Email, Report];
}
