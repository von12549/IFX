namespace IFX.Modules.Auth.Domain.Identity.Events;

public record UserLoggedOutDomainEvent(
    Guid UserId,
    Guid LogoutEventId,
    TimeSpan SessionDuration);
