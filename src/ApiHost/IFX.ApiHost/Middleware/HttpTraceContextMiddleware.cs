using System.Diagnostics;

namespace IFX.ApiHost.Middleware;

public sealed class HttpTraceContextMiddleware(RequestDelegate next)
{
    internal const string TraceRestartedItemKey = "IFX.TraceRestarted";

    public async Task InvokeAsync(HttpContext context)
    {
        var traceParents = context.Request.Headers.GetCommaSeparatedValues("traceparent");
        var traceState = context.Request.Headers["tracestate"].FirstOrDefault();
        var invalidInboundTrace = traceParents.Length > 1 ||
            traceParents.Length == 1 && !ActivityContext.TryParse(traceParents[0], traceState, true, out _);

        context.Items[TraceRestartedItemKey] = invalidInboundTrace;

        Activity? ownedActivity = null;
        if (Activity.Current is null || Activity.Current.IdFormat != ActivityIdFormat.W3C)
        {
            ownedActivity = new Activity("IFX.ApiHost.HttpRequest");
            ownedActivity.SetIdFormat(ActivityIdFormat.W3C);
            ownedActivity.Start();
        }

        try
        {
            await next(context);
        }
        finally
        {
            ownedActivity?.Stop();
        }
    }
}
