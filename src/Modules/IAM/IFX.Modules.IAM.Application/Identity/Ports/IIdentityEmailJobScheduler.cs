namespace IFX.Modules.IAM.Application.Identity.Ports;

public sealed record IdentityEmailJob(
    string To,
    string? ToName,
    string Subject,
    string? HtmlBody,
    string? PlainTextBody);

public interface IIdentityEmailJobScheduler
{
    string Enqueue(IdentityEmailJob job);
}
