using IFX.Modules.IAM.Application.Identity.Ports;
using IFX.Platform.BackgroundJobs.Contracts;
using IFX.Platform.Notifications.Contracts;
using IFX.Platform.Notifications.Contracts.Models;

namespace IFX.Modules.IAM.Composition;

internal sealed class AuthEmailJobScheduler(IBackgroundJobService backgroundJobs) : IAuthEmailJobScheduler
{
    public string Enqueue(AuthEmailJob job) => backgroundJobs.Enqueue<IEmailService>(
        service => service.SendEmailAsync(
            new EmailMessage
            {
                To = job.To,
                ToName = job.ToName,
                Subject = job.Subject,
                HtmlBody = job.HtmlBody,
                PlainTextBody = job.PlainTextBody
            },
            default),
        "email");
}
