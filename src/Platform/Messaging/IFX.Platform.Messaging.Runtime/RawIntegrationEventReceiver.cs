using System.Diagnostics;
using System.Globalization;
using IFX.Platform.Messaging.Contracts.Messaging;
using Microsoft.Extensions.DependencyInjection;

namespace IFX.Platform.Messaging.Runtime;

public static class IntegrationEventTransportHeaders
{
    public const string EnvelopeVersion = "ifx-envelope-version";
    public const string EventId = "ifx-event-id";
    public const string EventType = "ifx-event-type";
    public const string SchemaVersion = "ifx-schema-version";
    public const string OccurredAt = "ifx-occurred-at";
    public const string Producer = "ifx-producer";
    public const string Scope = "ifx-scope";
    public const string TenantId = "ifx-tenant-id";
    public const string CorrelationId = "ifx-correlation-id";
    public const string CausationId = "ifx-causation-id";
    public const string ContentType = "content-type";
    public const string TraceParent = "traceparent";
    public const string TraceState = "tracestate";
    public const string Provenance = "ifx-provenance";
}

public sealed record InboundIntegrationEventMessage(
    IReadOnlyDictionary<string, string> Headers,
    string Payload);

public enum InboundIntegrationEventDisposition
{
    Accepted,
    Quarantined,
    Retry
}

public sealed record InboundIntegrationEventResult(
    InboundIntegrationEventDisposition Disposition,
    string ReasonCode,
    bool TraceRestarted);

public interface IInboundIntegrationEventReceiver
{
    Task<InboundIntegrationEventResult> ReceiveAsync(
        InboundIntegrationEventMessage message,
        CancellationToken cancellationToken);
}

public static class IntegrationEventTransportCodec
{
    public static InboundIntegrationEventMessage Encode(OutboxLogicalMessage message)
    {
        ArgumentNullException.ThrowIfNull(message);
        var envelope = message.Envelope;
        var headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            [IntegrationEventTransportHeaders.EnvelopeVersion] = envelope.EnvelopeVersion.ToString(CultureInfo.InvariantCulture),
            [IntegrationEventTransportHeaders.EventId] = envelope.EventId.ToString("D"),
            [IntegrationEventTransportHeaders.EventType] = envelope.EventType,
            [IntegrationEventTransportHeaders.SchemaVersion] = envelope.SchemaVersion.ToString(CultureInfo.InvariantCulture),
            [IntegrationEventTransportHeaders.OccurredAt] = envelope.OccurredAt.ToString("O", CultureInfo.InvariantCulture),
            [IntegrationEventTransportHeaders.Producer] = envelope.Producer,
            [IntegrationEventTransportHeaders.Scope] = envelope.Scope,
            [IntegrationEventTransportHeaders.CorrelationId] = envelope.CorrelationId.ToString("D"),
            [IntegrationEventTransportHeaders.CausationId] = envelope.CausationId.ToString("D"),
            [IntegrationEventTransportHeaders.ContentType] = envelope.ContentType,
            [IntegrationEventTransportHeaders.Provenance] = envelope.Provenance
        };

        if (envelope.TenantId is { } tenantId)
        {
            headers[IntegrationEventTransportHeaders.TenantId] = tenantId.ToString("D");
        }

        if (envelope.TraceParent is { } traceParent)
        {
            headers[IntegrationEventTransportHeaders.TraceParent] = traceParent;
        }

        if (envelope.TraceState is { } traceState)
        {
            headers[IntegrationEventTransportHeaders.TraceState] = traceState;
        }

        return new InboundIntegrationEventMessage(headers, message.Payload);
    }

    internal static DecodedInboundCarrier Decode(InboundIntegrationEventMessage message)
    {
        ArgumentNullException.ThrowIfNull(message);
        ArgumentNullException.ThrowIfNull(message.Headers);
        ArgumentNullException.ThrowIfNull(message.Payload);

        var headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var header in message.Headers)
        {
            if (string.IsNullOrWhiteSpace(header.Key) || !headers.TryAdd(header.Key, header.Value))
            {
                return DecodedInboundCarrier.Quarantine("G05-EVENT-CONTEXT-INVALID");
            }
        }

        if (!TryInt(headers, IntegrationEventTransportHeaders.EnvelopeVersion, out var envelopeVersion) ||
            !TryGuid(headers, IntegrationEventTransportHeaders.EventId, out var eventId) ||
            !TryInt(headers, IntegrationEventTransportHeaders.SchemaVersion, out var schemaVersion) || schemaVersion <= 0 ||
            !TryDateTimeOffset(headers, IntegrationEventTransportHeaders.OccurredAt, out var occurredAt) || occurredAt.Offset != TimeSpan.Zero ||
            !TryGuid(headers, IntegrationEventTransportHeaders.CorrelationId, out var correlationId) ||
            !TryGuid(headers, IntegrationEventTransportHeaders.CausationId, out var causationId) ||
            !TryRequired(headers, IntegrationEventTransportHeaders.EventType, out var eventType) ||
            !TryRequired(headers, IntegrationEventTransportHeaders.Producer, out var producer) ||
            !TryRequired(headers, IntegrationEventTransportHeaders.Scope, out var scope) ||
            !TryRequired(headers, IntegrationEventTransportHeaders.ContentType, out var contentType) ||
            !TryRequired(headers, IntegrationEventTransportHeaders.Provenance, out var provenance))
        {
            return DecodedInboundCarrier.Quarantine("G05-EVENT-CONTEXT-INVALID");
        }

        Guid? tenantId = null;
        if (scope == EventEnvelope.TenantScope)
        {
            if (!TryGuid(headers, IntegrationEventTransportHeaders.TenantId, out var parsedTenantId))
            {
                return DecodedInboundCarrier.Quarantine("G05-EVENT-TENANT-INVALID");
            }

            tenantId = parsedTenantId;
        }
        else if (scope != EventEnvelope.PlatformScope || headers.ContainsKey(IntegrationEventTransportHeaders.TenantId))
        {
            return DecodedInboundCarrier.Quarantine("G05-EVENT-TENANT-INVALID");
        }

        EventEnvelope envelope;
        try
        {
            envelope = new EventEnvelope(
                eventId,
                eventType,
                schemaVersion,
                occurredAt,
                producer,
                scope,
                tenantId,
                correlationId,
                causationId,
                contentType,
                provenance: provenance,
                envelopeVersion: envelopeVersion);
        }
        catch (ArgumentException)
        {
            return DecodedInboundCarrier.Quarantine("G05-EVENT-CONTEXT-INVALID");
        }

        var traceParentPresent = headers.TryGetValue(IntegrationEventTransportHeaders.TraceParent, out var traceParent);
        var traceStatePresent = headers.TryGetValue(IntegrationEventTransportHeaders.TraceState, out var traceState);
        var traceRestarted = false;
        var parentContext = default(ActivityContext);

        if (traceParentPresent)
        {
            try
            {
                var tracedEnvelope = new EventEnvelope(
                    eventId,
                    eventType,
                    schemaVersion,
                    occurredAt,
                    producer,
                    scope,
                    tenantId,
                    correlationId,
                    causationId,
                    contentType,
                    traceParent,
                    traceStatePresent ? traceState : null,
                    provenance,
                    envelopeVersion);

                if (ActivityContext.TryParse(traceParent, traceStatePresent ? traceState : null, true, out parentContext))
                {
                    envelope = tracedEnvelope;
                }
                else
                {
                    traceRestarted = true;
                }
            }
            catch (ArgumentException)
            {
                traceRestarted = true;
            }
        }
        else if (traceStatePresent)
        {
            traceRestarted = true;
        }

        if (traceRestarted)
        {
            parentContext = default;
        }

        return new DecodedInboundCarrier(
            new OutboxLogicalMessage(envelope, message.Payload),
            parentContext,
            traceRestarted,
            null);
    }

    private static bool TryRequired(IReadOnlyDictionary<string, string> headers, string name, out string value)
    {
        value = string.Empty;
        if (!headers.TryGetValue(name, out var candidate) || string.IsNullOrWhiteSpace(candidate))
        {
            return false;
        }

        value = candidate;
        return true;
    }

    private static bool TryGuid(IReadOnlyDictionary<string, string> headers, string name, out Guid value)
    {
        value = default;
        return headers.TryGetValue(name, out var candidate) &&
            Guid.TryParseExact(candidate, "D", out value) &&
            value != Guid.Empty;
    }

    private static bool TryInt(IReadOnlyDictionary<string, string> headers, string name, out int value)
    {
        value = default;
        return headers.TryGetValue(name, out var candidate) &&
            int.TryParse(candidate, NumberStyles.None, CultureInfo.InvariantCulture, out value);
    }

    private static bool TryDateTimeOffset(
        IReadOnlyDictionary<string, string> headers,
        string name,
        out DateTimeOffset value)
    {
        value = default;
        return headers.TryGetValue(name, out var candidate) &&
            DateTimeOffset.TryParseExact(candidate, "O", CultureInfo.InvariantCulture, DateTimeStyles.None, out value);
    }
}

public sealed class RawIntegrationEventReceiver(IServiceScopeFactory scopeFactory)
    : IInboundIntegrationEventReceiver
{
    public const string ActivitySourceName = "IFX.Platform.Messaging.Inbound";
    private static readonly ActivitySource ActivitySource = new(ActivitySourceName, "1.0.0");

    public async Task<InboundIntegrationEventResult> ReceiveAsync(
        InboundIntegrationEventMessage message,
        CancellationToken cancellationToken)
    {
        var decoded = IntegrationEventTransportCodec.Decode(message);
        if (decoded.Message is null)
        {
            return new InboundIntegrationEventResult(
                InboundIntegrationEventDisposition.Quarantined,
                decoded.ReasonCode!,
                false);
        }

        using var activity = ActivitySource.StartActivity(
            "integration-event.consume",
            ActivityKind.Consumer,
            decoded.ParentContext);
        activity?.SetTag("ifx.trace.restarted", decoded.TraceRestarted);
        activity?.SetTag("ifx.envelope.version", decoded.Message.Envelope.EnvelopeVersion);

        await using var scope = scopeFactory.CreateAsyncScope();
        var handlers = scope.ServiceProvider.GetServices<IInboundIntegrationEventHandler>()
            .Where(handler => handler.CanHandle(
                decoded.Message.Envelope.EventType,
                decoded.Message.Envelope.SchemaVersion))
            .ToArray();
        if (handlers.Length == 0)
        {
            return new InboundIntegrationEventResult(
                InboundIntegrationEventDisposition.Retry,
                "G05-EVENT-HANDLER-UNAVAILABLE",
                decoded.TraceRestarted);
        }

        foreach (var handler in handlers)
        {
            await handler.HandleAsync(decoded.Message, cancellationToken);
        }

        return new InboundIntegrationEventResult(
            InboundIntegrationEventDisposition.Accepted,
            decoded.TraceRestarted ? "G05-EVENT-TRACE-RESTARTED" : "ACCEPTED",
            decoded.TraceRestarted);
    }
}

internal sealed record DecodedInboundCarrier(
    OutboxLogicalMessage? Message,
    ActivityContext ParentContext,
    bool TraceRestarted,
    string? ReasonCode)
{
    public static DecodedInboundCarrier Quarantine(string reasonCode) =>
        new(null, default, false, reasonCode);
}
