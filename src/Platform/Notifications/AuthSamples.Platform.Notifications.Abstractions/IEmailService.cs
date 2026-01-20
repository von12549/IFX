using AuthSamples.Platform.Notifications.Abstractions.Models;

namespace AuthSamples.Platform.Notifications.Abstractions;

/// <summary>
/// Service for sending email notifications.
/// </summary>
public interface IEmailService
{
    /// <summary>
    /// Sends an email message.
    /// </summary>
    /// <param name="message">The email message to send.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The result of the send operation.</returns>
    Task<EmailResult> SendEmailAsync(EmailMessage message, CancellationToken cancellationToken = default);

    /// <summary>
    /// Sends a templated email using a provider-specific template.
    /// </summary>
    /// <param name="message">The templated email message to send.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The result of the send operation.</returns>
    Task<EmailResult> SendTemplatedEmailAsync(TemplatedEmailMessage message, CancellationToken cancellationToken = default);

    /// <summary>
    /// Sends multiple emails in a batch.
    /// </summary>
    /// <param name="messages">The email messages to send.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The results of each send operation.</returns>
    Task<IReadOnlyList<EmailResult>> SendBatchAsync(IEnumerable<EmailMessage> messages, CancellationToken cancellationToken = default);
}
