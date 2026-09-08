namespace IFX.Platform.Notifications.Contracts.Models;

public sealed record TemplatedEmailMessage
{
    public required string To { get; init; }
    public string? ToName { get; init; }
    public required string TemplateId { get; init; }
    public IDictionary<string, object>? TemplateData { get; init; }
    public string? From { get; init; }
    public string? FromName { get; init; }
}
