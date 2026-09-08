using IFX.Platform.Notifications.Contracts;
using IFX.Platform.Notifications.Contracts.Models;
using Microsoft.Extensions.Logging;
using SendGrid;
using SendGrid.Helpers.Mail;

namespace IFX.Platform.Notifications.Infrastructure.SendGrid;

/// <summary>
/// SendGrid implementation of <see cref="IEmailService"/>.
/// </summary>
public class SendGridEmailService : IEmailService
{
    private readonly ISendGridClient _client;
    private readonly SendGridSettings _settings;
    private readonly ILogger<SendGridEmailService> _logger;

    public SendGridEmailService(
        ISendGridClient client,
        SendGridSettings settings,
        ILogger<SendGridEmailService> logger)
    {
        _client = client;
        _settings = settings;
        _logger = logger;
    }

    public async Task<EmailResult> SendEmailAsync(EmailMessage message, CancellationToken cancellationToken = default)
    {
        try
        {
            var msg = BuildSendGridMessage(message);
            var response = await _client.SendEmailAsync(msg, cancellationToken);

            if (response.IsSuccessStatusCode)
            {
                var messageId = response.Headers.TryGetValues("X-Message-Id", out var values)
                    ? values.FirstOrDefault()
                    : null;

                _logger.LogInformation("Email delivery accepted with {MessageId}", messageId);

                return EmailResult.Success(messageId);
            }

            _logger.LogError("Email delivery failed with {Status}", response.StatusCode);

            return EmailResult.Failure("email_provider_rejected");
        }
        catch (Exception ex)
        {
            _logger.LogError("Email delivery failed with {FailureType}", ex.GetType().Name);
            return EmailResult.Failure("email_provider_unavailable");
        }
    }

    public async Task<EmailResult> SendTemplatedEmailAsync(TemplatedEmailMessage message, CancellationToken cancellationToken = default)
    {
        try
        {
            var msg = new SendGridMessage();

            // Set from
            var fromEmail = message.From ?? _settings.DefaultFromEmail;
            var fromName = message.FromName ?? _settings.DefaultFromName;
            msg.SetFrom(new EmailAddress(fromEmail, fromName));

            // Set to
            msg.AddTo(new EmailAddress(message.To, message.ToName));

            // Set template
            msg.SetTemplateId(message.TemplateId);

            // Set template data
            if (message.TemplateData != null)
            {
                msg.SetTemplateData(message.TemplateData);
            }

            var response = await _client.SendEmailAsync(msg, cancellationToken);

            if (response.IsSuccessStatusCode)
            {
                var messageId = response.Headers.TryGetValues("X-Message-Id", out var values)
                    ? values.FirstOrDefault()
                    : null;

                _logger.LogInformation("Templated email delivery accepted for {TemplateId} with {MessageId}",
                    message.TemplateId, messageId);

                return EmailResult.Success(messageId);
            }

            _logger.LogError("Templated email delivery failed with {Status}", response.StatusCode);

            return EmailResult.Failure("email_provider_rejected");
        }
        catch (Exception ex)
        {
            _logger.LogError("Templated email delivery failed with {FailureType}", ex.GetType().Name);
            return EmailResult.Failure("email_provider_unavailable");
        }
    }

    public async Task<IReadOnlyList<EmailResult>> SendBatchAsync(IEnumerable<EmailMessage> messages, CancellationToken cancellationToken = default)
    {
        var results = new List<EmailResult>();

        foreach (var message in messages)
        {
            var result = await SendEmailAsync(message, cancellationToken);
            results.Add(result);
        }

        return results;
    }

    private SendGridMessage BuildSendGridMessage(EmailMessage message)
    {
        var msg = new SendGridMessage();

        // Set from
        var fromEmail = message.From ?? _settings.DefaultFromEmail;
        var fromName = message.FromName ?? _settings.DefaultFromName;
        msg.SetFrom(new EmailAddress(fromEmail, fromName));

        // Set to
        msg.AddTo(new EmailAddress(message.To, message.ToName));

        // Set subject
        msg.SetSubject(message.Subject);

        // Set body
        if (!string.IsNullOrEmpty(message.PlainTextBody))
        {
            msg.AddContent(MimeType.Text, message.PlainTextBody);
        }

        if (!string.IsNullOrEmpty(message.HtmlBody))
        {
            msg.AddContent(MimeType.Html, message.HtmlBody);
        }

        // Set reply-to
        if (!string.IsNullOrEmpty(message.ReplyTo))
        {
            msg.SetReplyTo(new EmailAddress(message.ReplyTo));
        }

        // Set CC
        if (message.Cc?.Any() == true)
        {
            msg.AddCcs(message.Cc.Select(cc => new EmailAddress(cc)).ToList());
        }

        // Set BCC
        if (message.Bcc?.Any() == true)
        {
            msg.AddBccs(message.Bcc.Select(bcc => new EmailAddress(bcc)).ToList());
        }

        return msg;
    }
}
