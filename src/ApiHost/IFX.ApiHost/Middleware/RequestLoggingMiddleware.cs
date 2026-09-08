using System.Diagnostics;

namespace IFX.ApiHost.Middleware;

public class RequestLoggingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<RequestLoggingMiddleware> _logger;

    public RequestLoggingMiddleware(
        RequestDelegate next,
        ILogger<RequestLoggingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var stopwatch = Stopwatch.StartNew();
        var requestPath = context.Request.Path;
        var requestMethod = context.Request.Method;
        var correlationId = HttpCorrelationMiddleware.GetCorrelation(context).ToString("D");

        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["CorrelationId"] = correlationId
        });

        _logger.LogInformation(
            "HTTP {Method} {Path} started [CorrelationId: {CorrelationId}]",
            requestMethod,
            requestPath,
            correlationId);

        try
        {
            await _next(context);
        }
        finally
        {
            stopwatch.Stop();
            var statusCode = context.Response.StatusCode;
            var elapsedMilliseconds = stopwatch.ElapsedMilliseconds;
            var operationId = context.Items.TryGetValue(HttpExecutionContextMiddleware.OperationItemKey, out var value)
                ? value?.ToString() ?? "unavailable"
                : "unavailable";

            var logLevel = statusCode >= 500
                ? LogLevel.Error
                : statusCode >= 400
                    ? LogLevel.Warning
                    : LogLevel.Information;

            _logger.Log(
                logLevel,
                "HTTP {Method} {Path} responded {StatusCode} in {ElapsedMilliseconds}ms [CorrelationId: {CorrelationId}, OperationId: {OperationId}]",
                requestMethod,
                requestPath,
                statusCode,
                elapsedMilliseconds,
                correlationId,
                operationId);
        }
    }
}
