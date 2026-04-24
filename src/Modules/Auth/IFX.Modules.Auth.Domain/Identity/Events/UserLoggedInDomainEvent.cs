namespace IFX.Modules.Auth.Domain.Identity.Events;

public record UserLoggedInDomainEvent(
    Guid UserId,
    Guid LoginEventId,
    DateTimeOffset Timestamp);
