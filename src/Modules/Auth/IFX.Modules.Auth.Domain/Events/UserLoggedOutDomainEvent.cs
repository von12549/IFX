namespace IFX.Modules.Auth.Domain.Events;

public record UserLoggedOutDomainEvent(
    Guid UserId,
    Guid LogoutEventId,
    TimeSpan SessionDuration);
