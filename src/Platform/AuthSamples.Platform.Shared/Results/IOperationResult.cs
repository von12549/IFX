namespace AuthSamples.Platform.Shared.Results;

/// <summary>
/// Represents the result of a platform operation.
/// </summary>
public interface IOperationResult
{
    /// <summary>
    /// Gets whether the operation was successful.
    /// </summary>
    bool IsSuccess { get; }

    /// <summary>
    /// Gets the error message if the operation failed.
    /// </summary>
    string? ErrorMessage { get; }
}

/// <summary>
/// Represents the result of a platform operation with a typed identifier.
/// </summary>
/// <typeparam name="TId">The type of the result identifier.</typeparam>
public interface IOperationResult<TId> : IOperationResult
{
    /// <summary>
    /// Gets the identifier from the operation (e.g., message ID, job ID).
    /// </summary>
    TId? ResultId { get; }
}
