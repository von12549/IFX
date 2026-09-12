namespace IFX.Modules.IAM.Domain.Identity.Events;

public record UserLoggedInDomainEvent(
    Guid UserId,
    Guid LoginEventId,
    DateTimeOffset Timestamp);
