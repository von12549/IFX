using IFX.Platform.Notifications.Contracts.Models;

namespace IFX.Platform.Notifications.Contracts;

public interface IEmailService
{
    Task<EmailResult> SendEmailAsync(EmailMessage message, CancellationToken cancellationToken = default);
    Task<EmailResult> SendTemplatedEmailAsync(TemplatedEmailMessage message, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<EmailResult>> SendBatchAsync(IEnumerable<EmailMessage> messages, CancellationToken cancellationToken = default);
}
