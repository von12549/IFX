namespace AuthSamples.Platform.Notifications.Abstractions.Models;

/// <summary>
/// Represents a templated email message using a provider-specific template.
/// </summary>
public record TemplatedEmailMessage
{
    /// <summary>
    /// The recipient's email address.
    /// </summary>
    public required string To { get; init; }

    /// <summary>
    /// The recipient's display name (optional).
    /// </summary>
    public string? ToName { get; init; }

    /// <summary>
    /// The template ID (provider-specific, e.g., SendGrid template ID).
    /// </summary>
    public required string TemplateId { get; init; }

    /// <summary>
    /// Dynamic template data to substitute in the template.
    /// </summary>
    public IDictionary<string, object>? TemplateData { get; init; }

    /// <summary>
    /// The sender's email address (optional, uses default if not specified).
    /// </summary>
    public string? From { get; init; }

    /// <summary>
    /// The sender's display name (optional).
    /// </summary>
    public string? FromName { get; init; }
}
