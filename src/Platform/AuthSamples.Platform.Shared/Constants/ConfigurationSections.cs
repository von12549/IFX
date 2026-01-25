namespace AuthSamples.Platform.Shared.Constants;

/// <summary>
/// Configuration section names for platform services.
/// </summary>
public static class ConfigurationSections
{
    /// <summary>
    /// Section name for background jobs configuration.
    /// </summary>
    public const string BackgroundJobs = "BackgroundJobs";

    /// <summary>
    /// Section name for notifications configuration.
    /// </summary>
    public const string Notifications = "Notifications";

    /// <summary>
    /// Section name for SendGrid-specific configuration.
    /// </summary>
    public const string NotificationsSendGrid = "Notifications:SendGrid";
}
