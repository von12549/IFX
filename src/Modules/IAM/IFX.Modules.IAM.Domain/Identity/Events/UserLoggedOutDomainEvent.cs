namespace IFX.Modules.IAM.Domain.Identity.Events;

public record UserLoggedOutDomainEvent(
    Guid UserId,
    Guid LogoutEventId,
    TimeSpan SessionDuration);
