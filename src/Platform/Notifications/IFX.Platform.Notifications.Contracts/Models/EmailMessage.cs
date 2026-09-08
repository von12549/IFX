namespace IFX.Platform.Notifications.Contracts.Models;

public sealed record EmailMessage
{
    public required string To { get; init; }
    public string? ToName { get; init; }
    public required string Subject { get; init; }
    public string? PlainTextBody { get; init; }
    public string? HtmlBody { get; init; }
    public string? From { get; init; }
    public string? FromName { get; init; }
    public string? ReplyTo { get; init; }
    public IReadOnlyList<string>? Cc { get; init; }
    public IReadOnlyList<string>? Bcc { get; init; }
}
