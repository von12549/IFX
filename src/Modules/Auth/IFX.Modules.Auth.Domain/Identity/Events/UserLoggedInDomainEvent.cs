namespace IFX.Modules.Auth.Domain.Events;

public record UserLoggedInDomainEvent(
    Guid UserId,
    Guid LoginEventId,
    DateTime Timestamp);
