using System.Text.Json;
using IFX.BuildingBlocks.Application.Context;
using IFX.BuildingBlocks.Application.Events;
using IFX.Modules.Holdings.Application.Integrations;
using IFX.Modules.Holdings.Infrastructure.Messaging;
using IFX.Modules.Holdings.Infrastructure.Persistence;
using IFX.Modules.Registry.Contracts.V1.Events;
using IFX.Modules.Transaction.Contracts.V1.Events;
using IFX.Platform.Messaging.Contracts.Messaging;
using IFX.Platform.Messaging.Runtime;
using MediatR;

namespace IFX.Modules.Holdings.Infrastructure.Integrations;

public sealed class HoldingsInboundIntegrationEventHandler(
    ISender sender,
    HoldingsDbContext dbContext,
    IExecutionContextScopeFactory contextScopeFactory) : IInboundIntegrationEventHandler
{
    private static readonly JsonSerializerOptions SerializerOptions = new(JsonSerializerDefaults.Web);

    public bool CanHandle(string eventType, int schemaVersion) => schemaVersion == 1 && eventType is
        TransactionProcessedV1.EventType or ClassStatusChangedV1.EventType;

    public async Task HandleAsync(OutboxLogicalMessage message, CancellationToken cancellationToken)
    {
        var envelope = message.Envelope;
        var reason = Validate(envelope);
        if (reason is not null)
        {
            await QuarantineAsync(envelope, reason, cancellationToken);
            return;
        }

        var tenantId = envelope.TenantId!.Value;
        var metadata = new IntegrationEventMetadata(envelope.EventId, tenantId, envelope.CorrelationId.ToString("D"), envelope.CausationId.ToString("D"));
        var executionContext = ExecutionContextSnapshot.ForTenant(
            envelope.CorrelationId,
            envelope.EventId,
            envelope.CausationId,
            tenantId,
            "service",
            envelope.Producer,
            envelope.Producer,
            "integration-event",
            envelope.SchemaVersion);

        using var scope = contextScopeFactory.Push(executionContext);
        try
        {
            if (envelope.EventType == TransactionProcessedV1.EventType)
            {
                var payload = JsonSerializer.Deserialize<TransactionProcessedV1>(message.Payload, SerializerOptions)
                    ?? throw new JsonException("Empty transaction event payload.");
                var result = await sender.Send(new ApplyTransactionProcessedCommand(metadata, payload.TransactionId, payload.TransactionType, payload.InvestmentAccountId, payload.ClassId, payload.TargetClassId, payload.Units, payload.NavPrice), cancellationToken);
                if (!result.IsSuccess)
                {
                    await QuarantineAsync(envelope, "G05-EVENT-BUSINESS-REJECTED", cancellationToken);
                }
            }
            else
            {
                var payload = JsonSerializer.Deserialize<ClassStatusChangedV1>(message.Payload, SerializerOptions)
                    ?? throw new JsonException("Empty class event payload.");
                var result = await sender.Send(new ApplyClassStatusChangedCommand(metadata, payload.ClassId, payload.FundId, payload.OldStatus, payload.NewStatus), cancellationToken);
                if (!result.IsSuccess)
                {
                    await QuarantineAsync(envelope, "G05-EVENT-BUSINESS-REJECTED", cancellationToken);
                }
            }
        }
        catch (JsonException)
        {
            await QuarantineAsync(envelope, "G05-EVENT-PAYLOAD-INVALID", cancellationToken);
        }
    }

    private static string? Validate(EventEnvelope envelope)
    {
        if (envelope.Scope != EventEnvelope.TenantScope || envelope.TenantId is null || envelope.TenantId == Guid.Empty) return "G05-EVENT-TENANT-INVALID";
        if (envelope.EventType == TransactionProcessedV1.EventType && envelope.Producer != "ifx.transaction") return "G05-EVENT-PRODUCER-INVALID";
        if (envelope.EventType == ClassStatusChangedV1.EventType && envelope.Producer != "ifx.registry") return "G05-EVENT-PRODUCER-INVALID";
        return null;
    }

    private async Task QuarantineAsync(EventEnvelope envelope, string reasonCode, CancellationToken cancellationToken)
    {
        dbContext.QuarantinedMessages.Add(new HoldingsQuarantinedMessage
        {
            Id = Guid.NewGuid(), EventId = envelope.EventId, EventType = envelope.EventType,
            ReasonCode = reasonCode, QuarantinedAt = DateTimeOffset.UtcNow
        });
        await dbContext.SaveChangesAsync(cancellationToken);
    }
}
