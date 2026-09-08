namespace IFX.Platform.Notifications.Contracts.Models;

public sealed record EmailResult
{
    public required bool IsSuccess { get; init; }
    public string? MessageId { get; init; }
    public string? ErrorMessage { get; init; }

    public static EmailResult Success(string? messageId = null) => new() { IsSuccess = true, MessageId = messageId };
    public static EmailResult Failure(string errorMessage) => new() { IsSuccess = false, ErrorMessage = errorMessage };
}
