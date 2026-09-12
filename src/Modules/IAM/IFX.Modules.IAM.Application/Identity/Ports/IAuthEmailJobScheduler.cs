namespace IFX.Modules.IAM.Application.Identity.Ports;

public sealed record AuthEmailJob(
    string To,
    string? ToName,
    string Subject,
    string? HtmlBody,
    string? PlainTextBody);

public interface IAuthEmailJobScheduler
{
    string Enqueue(AuthEmailJob job);
}
