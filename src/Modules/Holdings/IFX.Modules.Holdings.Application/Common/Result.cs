using IFX.BuildingBlocks.Application.Results;

namespace IFX.Modules.Holdings.Application.Common;

public class Result<T> : IOperationResult
{
    public bool IsSuccess { get; }
    public T? Value { get; }
    public string? Error { get; }
    public OperationErrorCategory ErrorCategory { get; }

    private Result(
        bool isSuccess,
        T? value,
        string? error,
        OperationErrorCategory errorCategory = OperationErrorCategory.None)
    {
        IsSuccess = isSuccess;
        Value = value;
        Error = error;
        ErrorCategory = errorCategory;
    }

    public static Result<T> Success(T value) => new(true, value, null);
    public static Result<T> Failure(
        string error,
        OperationErrorCategory errorCategory = OperationErrorCategory.BusinessRule) =>
        new(false, default, error, errorCategory);
}
