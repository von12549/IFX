using IFX.Platform.Shared.Configuration;
using IFX.Platform.Shared.Constants;

namespace IFX.Platform.Notifications.Infrastructure.SendGrid;

/// <summary>
/// Configuration settings for SendGrid email service.
/// </summary>
public class SendGridSettings : IPlatformSettings
{
    /// <summary>
    /// Configuration section name.
    /// </summary>
    public static string SectionName => ConfigurationSections.NotificationsSendGrid;

    /// <summary>
    /// Whether the email service is enabled.
    /// </summary>
    public bool Enabled => !string.IsNullOrEmpty(ApiKey);

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
