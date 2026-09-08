using IFX.Platform.Notifications.Contracts;
using IFX.Platform.Notifications.Contracts.Models;
using Microsoft.Extensions.Logging;

namespace IFX.Platform.Notifications.Composition;

/// <summary>
/// No-op implementation of <see cref="IEmailService"/> for development/testing.
/// Records only bounded delivery events and does not actually send emails.
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
        _logger.LogInformation("[NoOp] Email delivery accepted");

        return Task.FromResult(EmailResult.Success("noop-message-id"));
    }

    public Task<EmailResult> SendTemplatedEmailAsync(TemplatedEmailMessage message, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("[NoOp] Templated email delivery accepted");

        return Task.FromResult(EmailResult.Success("noop-message-id"));
    }

    public Task<IReadOnlyList<EmailResult>> SendBatchAsync(IEnumerable<EmailMessage> messages, CancellationToken cancellationToken = default)
    {
        var results = new List<EmailResult>();

        foreach (var _ in messages)
        {
            _logger.LogInformation("[NoOp] Batch email delivery accepted");

            results.Add(EmailResult.Success("noop-message-id"));
        }

        return Task.FromResult<IReadOnlyList<EmailResult>>(results);
    }
}
