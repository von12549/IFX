namespace AuthSamples.Modules.Auth.Domain.Events;

public record UserLoggedInDomainEvent(
    Guid UserId,
    Guid LoginEventId,
    DateTime Timestamp);
