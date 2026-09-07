using System.Net;
using System.Text.Json;
using FluentValidation;
using IFX.BuildingBlocks.Application.Transactions;
using IFX.BuildingBlocks.Security.Authorization.Exceptions;

namespace IFX.ApiHost.Middleware;

public class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    public ExceptionHandlingMiddleware(
        RequestDelegate next,
        ILogger<ExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (OperationCanceledException)
        {
            // Cancellation is control flow. Preserve it for the server and do not log it as an error.
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "An unhandled exception occurred: {Message}", ex.Message);
            await HandleExceptionAsync(context, ex);
        }
    }

    private static Task HandleExceptionAsync(HttpContext context, Exception exception)
    {
        var statusCode = HttpStatusCode.InternalServerError;
        var message = "An internal server error occurred. Please try again later.";

        var response = new ErrorResponse
        {
            Success = false,
            Error = message,
            Timestamp = DateTimeOffset.UtcNow
        };

        if (exception is ValidationException validationException)
        {
            statusCode = HttpStatusCode.BadRequest;
            response.Error = "One or more validation errors occurred.";
            response.Errors = validationException.Errors
                .GroupBy(failure => failure.PropertyName)
                .ToDictionary(
                    group => group.Key,
                    group => group.Select(failure => failure.ErrorMessage).Distinct().ToArray());
        }
        else if (exception is ForbiddenException)
        {
            statusCode = HttpStatusCode.Forbidden;
            response.Error = exception.Message;
        }
        else if (exception is ConcurrencyConflictException)
        {
            statusCode = HttpStatusCode.Conflict;
            response.Error = "The resource was changed by another request. Reload it before retrying.";
        }
        else if (exception is TransactionCommitOutcomeUnknownException)
        {
            statusCode = HttpStatusCode.ServiceUnavailable;
            response.Error = "The operation outcome could not be confirmed. Reconcile it before retrying.";
        }
        else if (exception is ArgumentException or ArgumentNullException)
        {
            statusCode = HttpStatusCode.BadRequest;
            response.Error = exception.Message;
        }
        else if (exception is UnauthorizedAccessException)
        {
            statusCode = HttpStatusCode.Unauthorized;
            response.Error = "Unauthorized access.";
        }
        else if (exception is KeyNotFoundException)
        {
            statusCode = HttpStatusCode.NotFound;
            response.Error = exception.Message;
        }

        context.Response.ContentType = "application/json";
        context.Response.StatusCode = (int)statusCode;

        var jsonOptions = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        };

        return context.Response.WriteAsync(JsonSerializer.Serialize(response, jsonOptions));
    }
}

public class ErrorResponse
{
    public bool Success { get; set; }
    public object? Data { get; set; }
    public string? Error { get; set; }
    public Dictionary<string, string[]>? Errors { get; set; }
    public DateTimeOffset Timestamp { get; set; }
}
