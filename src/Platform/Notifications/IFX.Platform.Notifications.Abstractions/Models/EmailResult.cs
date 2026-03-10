using IFX.Platform.Shared.Results;

namespace IFX.Platform.Notifications.Abstractions.Models;

/// <summary>
/// Represents the result of sending an email.
/// </summary>
public record EmailResult : IOperationResult<string>
{
    /// <summary>
    /// Whether the email was sent successfully.
    /// </summary>
    public required bool IsSuccess { get; init; }

    /// <summary>
    /// The message ID from the email provider (if available).
    /// </summary>
    public string? MessageId { get; init; }

    /// <summary>
    /// The result identifier (message ID).
    /// </summary>
    string? IOperationResult<string>.ResultId => MessageId;

    /// <summary>
    /// Error message if the send failed.
    /// </summary>
    public string? ErrorMessage { get; init; }

    /// <summary>
    /// Creates a successful result.
    /// </summary>
    public static EmailResult Success(string? messageId = null) => new()
    {
        IsSuccess = true,
        MessageId = messageId
    };

    /// <summary>
    /// Creates a failure result.
    /// </summary>
    public static EmailResult Failure(string errorMessage) => new()
    {
        IsSuccess = false,
        ErrorMessage = errorMessage
    };
}
