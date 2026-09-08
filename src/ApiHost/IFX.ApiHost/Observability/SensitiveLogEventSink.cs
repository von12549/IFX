using IFX.BuildingBlocks.Application.Observability;
using Serilog.Core;
using Serilog.Events;

namespace IFX.ApiHost.Observability;

public sealed class SensitiveLogEventSink(Serilog.ILogger destination, SensitiveTelemetryRedactor redactor)
    : ILogEventSink, IDisposable
{
    public void Emit(LogEvent logEvent)
    {
        var properties = new List<LogEventProperty>();
        foreach (var property in logEvent.Properties)
        {
            var result = redactor.Redact(property.Key, property.Value);
            if (result.Handling == TelemetryValueHandling.Drop)
            {
                continue;
            }

            properties.Add(new LogEventProperty(
                property.Key,
                result.Handling == TelemetryValueHandling.Allow
                    ? property.Value
                    : new ScalarValue(result.Value)));
        }

        if (logEvent.Exception is { } exception)
        {
            properties.RemoveAll(property => property.Name == "FailureType");
            properties.Add(new LogEventProperty("FailureType", new ScalarValue(exception.GetType().Name)));
        }

        var safeEvent = new LogEvent(
            logEvent.Timestamp,
            logEvent.Level,
            exception: null,
            logEvent.MessageTemplate,
            properties);
        destination.Write(safeEvent);
    }

    public void Dispose()
    {
        if (destination is IDisposable disposable)
        {
            disposable.Dispose();
        }
    }
}
