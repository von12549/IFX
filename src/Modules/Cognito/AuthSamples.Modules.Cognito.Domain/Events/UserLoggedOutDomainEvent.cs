namespace AuthSamples.Modules.Cognito.Domain.Events;

public record UserLoggedOutDomainEvent(
    Guid UserId,
    Guid LogoutEventId,
    TimeSpan SessionDuration);
