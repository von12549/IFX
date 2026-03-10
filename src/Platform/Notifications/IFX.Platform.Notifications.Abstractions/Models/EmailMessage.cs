namespace IFX.Platform.Notifications.Abstractions.Models;

/// <summary>
/// Represents an email message to be sent.
/// </summary>
public record EmailMessage
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
    /// The email subject.
    /// </summary>
    public required string Subject { get; init; }

    /// <summary>
    /// The plain text body of the email.
    /// </summary>
    public string? PlainTextBody { get; init; }

    /// <summary>
    /// The HTML body of the email.
    /// </summary>
    public string? HtmlBody { get; init; }

    /// <summary>
    /// The sender's email address (optional, uses default if not specified).
    /// </summary>
    public string? From { get; init; }

    /// <summary>
    /// The sender's display name (optional).
    /// </summary>
    public string? FromName { get; init; }

    /// <summary>
    /// Reply-to email address (optional).
    /// </summary>
    public string? ReplyTo { get; init; }

    /// <summary>
    /// CC recipients (optional).
    /// </summary>
    public IReadOnlyList<string>? Cc { get; init; }

    /// <summary>
    /// BCC recipients (optional).
    /// </summary>
    public IReadOnlyList<string>? Bcc { get; init; }
}
