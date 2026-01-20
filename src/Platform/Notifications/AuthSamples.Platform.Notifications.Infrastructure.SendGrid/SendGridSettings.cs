namespace AuthSamples.Platform.Notifications.Infrastructure.SendGrid;

/// <summary>
/// Configuration settings for SendGrid email service.
/// </summary>
public class SendGridSettings
{
    /// <summary>
    /// Configuration section name.
    /// </summary>
    public const string SectionName = "Notifications:SendGrid";

    /// <summary>
    /// SendGrid API key.
    /// </summary>
    public string ApiKey { get; set; } = string.Empty;

    /// <summary>
    /// Default sender email address.
    /// </summary>
    public string DefaultFromEmail { get; set; } = string.Empty;

    /// <summary>
    /// Default sender display name.
    /// </summary>
    public string DefaultFromName { get; set; } = string.Empty;

    /// <summary>
    /// Whether to enable sandbox mode (emails are validated but not sent).
    /// </summary>
    public bool SandboxMode { get; set; } = false;
}
