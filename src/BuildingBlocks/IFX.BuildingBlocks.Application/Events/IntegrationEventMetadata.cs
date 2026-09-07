namespace IFX.BuildingBlocks.Application.Events;

/// <summary>
/// Transport-neutral metadata passed by an inbound adapter to an Inbox command.
/// The adapter maps protocol headers; the owning module controls deduplication and persistence.
/// </summary>
public sealed record IntegrationEventMetadata(
    Guid EventId,
    Guid TenantId,
    string? CorrelationId,
    string? CausationId);
