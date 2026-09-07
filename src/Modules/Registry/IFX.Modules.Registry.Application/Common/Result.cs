using IFX.BuildingBlocks.Application.Results;

namespace IFX.Modules.Registry.Application.Common;

public class Result<T> : IOperationResult
{
    public bool IsSuccess { get; }
    public T? Value { get; }
    public string? Error { get; }
    public List<string>? Errors { get; }
    public OperationErrorCategory ErrorCategory { get; }

    private Result(
        bool isSuccess,
        T? value,
        string? error,
        List<string>? errors = null,
        OperationErrorCategory errorCategory = OperationErrorCategory.None)
    {
        IsSuccess = isSuccess;
        Value = value;
        Error = error;
        Errors = errors;
        ErrorCategory = errorCategory;
    }

    public static Result<T> Success(T value) => new(true, value, null, null);
    public static Result<T> Failure(
        string error,
        OperationErrorCategory errorCategory = OperationErrorCategory.BusinessRule) =>
        new(false, default, error, null, errorCategory);
    public static Result<T> Failure(List<string> errors) =>
        new(false, default, errors.FirstOrDefault(), errors, OperationErrorCategory.Validation);
}

public class PagedResult<T>
{
    public IEnumerable<T> Items { get; set; } = new List<T>();
    public int TotalCount { get; set; }
    public int PageNumber { get; set; }
    public int PageSize { get; set; }
    public int TotalPages => (int)Math.Ceiling(TotalCount / (double)PageSize);
    public bool HasPreviousPage => PageNumber > 1;
    public bool HasNextPage => PageNumber < TotalPages;
}
