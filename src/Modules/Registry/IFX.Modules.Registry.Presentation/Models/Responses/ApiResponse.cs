namespace IFX.Modules.Registry.Presentation.Models.Responses;

public class ApiResponse<T>
{
    public bool Success { get; set; }
    public T? Data { get; set; }
    public string? Error { get; set; }
    public List<string>? Errors { get; set; }
    public DateTimeOffset Timestamp { get; set; } = DateTimeOffset.UtcNow;

    public static ApiResponse<T> SuccessResponse(T data)
    {
        return new ApiResponse<T>
        {
            Success = true,
            Data = data,
            Error = null,
            Errors = null
        };
    }

    public static ApiResponse<T> FailureResponse(string error)
    {
        return new ApiResponse<T>
        {
            Success = false,
            Data = default,
            Error = error,
            Errors = null
        };
    }

    public static ApiResponse<T> ValidationErrorResponse(List<string> errors)
    {
        return new ApiResponse<T>
        {
            Success = false,
            Data = default,
            Error = "Validation failed",
            Errors = errors
        };
    }
}
