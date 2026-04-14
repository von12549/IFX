namespace IFX.Platform.Messaging.Abstractions;

public interface IIntegrationEvent
{
    Guid EventId { get; }
    DateTime OccurredAt { get; }
}
