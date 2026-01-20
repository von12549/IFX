using AuthSamples.Platform.Notifications.Abstractions;
using AuthSamples.Platform.Notifications.Abstractions.Models;
using Microsoft.Extensions.Logging;

namespace AuthSamples.Platform.Notifications.Composition;

/// <summary>
/// No-op implementation of <see cref="IEmailService"/> for development/testing.
/// Logs email sends but does not actually send emails.
/// </summary>
public class NoOpEmailService : IEmailService
{
    private readonly ILogger<NoOpEmailService> _logger;

    public NoOpEmailService(ILogger<NoOpEmailService> logger)
    {
        _logger = logger;
    }

    public Task<EmailResult> SendEmailAsync(EmailMessage message, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "[NoOp] Would send email to {To}, Subject: {Subject}",
            message.To,
            message.Subject);

        return Task.FromResult(EmailResult.Success("noop-message-id"));
    }

    public Task<EmailResult> SendTemplatedEmailAsync(TemplatedEmailMessage message, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation(
            "[NoOp] Would send templated email to {To}, Template: {TemplateId}",
            message.To,
            message.TemplateId);

        return Task.FromResult(EmailResult.Success("noop-message-id"));
    }

    public Task<IReadOnlyList<EmailResult>> SendBatchAsync(IEnumerable<EmailMessage> messages, CancellationToken cancellationToken = default)
    {
        var results = new List<EmailResult>();

        foreach (var message in messages)
        {
            _logger.LogInformation(
                "[NoOp] Would send batch email to {To}, Subject: {Subject}",
                message.To,
                message.Subject);

            results.Add(EmailResult.Success("noop-message-id"));
        }

        return Task.FromResult<IReadOnlyList<EmailResult>>(results);
    }
}
