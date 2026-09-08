using System.Diagnostics;
using System.Text.Json;
using IFX.BuildingBlocks.Application.Context;
using IFX.Platform.Messaging.Contracts;
using IFX.Platform.Messaging.Contracts.Messaging;

namespace IFX.Platform.Messaging.Runtime;

public interface IOutboxMessageFactory
{
    OutboxLogicalMessage Create(object payload, string producer, string eventType, int schemaVersion, Guid tenantId);
}

public sealed class OutboxMessageFactory(IExecutionContextAccessor executionContext) : IOutboxMessageFactory
{
    private static readonly JsonSerializerOptions SerializerOptions = new(JsonSerializerDefaults.Web);

    public OutboxLogicalMessage Create(object payload, string producer, string eventType, int schemaVersion, Guid tenantId)
    {
        ArgumentNullException.ThrowIfNull(payload);
        _ = new EventSchemaIdentity(eventType, schemaVersion);

        var eventId = Guid.NewGuid();
        var context = executionContext.HasCurrent ? executionContext.Current : null;
        var correlationId = context?.CorrelationId.Value ?? eventId;
        var causationId = context?.OperationId.Value ?? eventId;
        var activity = Activity.Current;
        var traceParent = activity?.IdFormat == ActivityIdFormat.W3C ? activity.Id : null;
        var traceState = traceParent is null ? null : activity?.TraceStateString;
        var envelope = new EventEnvelope(
            eventId,
            eventType,
            schemaVersion,
            DateTimeOffset.UtcNow,
            producer,
            EventEnvelope.TenantScope,
            tenantId,
            correlationId,
            causationId,
            traceParent: traceParent,
            traceState: traceState);

        return new OutboxLogicalMessage(envelope, JsonSerializer.Serialize(payload, payload.GetType(), SerializerOptions));
    }
}
