using IFX.ApiHost.Runtime;

namespace IFX.ApiHost.Middleware;

public sealed class RuntimeDrainMiddleware(RequestDelegate next)
{
    public async Task InvokeAsync(HttpContext context, RuntimeDrainCoordinator coordinator)
    {
        if (context.Request.Path.StartsWithSegments("/health"))
        {
            await next(context);
            return;
        }

        if (!coordinator.TryBeginOperation(out var operation))
        {
            context.Response.StatusCode = StatusCodes.Status503ServiceUnavailable;
            context.Response.Headers.RetryAfter = "5";
            await context.Response.WriteAsJsonAsync(new
            {
                code = "G04-RUNTIME-DRAINING",
                retryable = true
            });
            return;
        }

        using (operation)
        {
            await next(context);
        }
    }
}
