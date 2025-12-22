namespace AuthSamples.Modules.Cognito.Domain.Events;

public record UserLoggedInDomainEvent(
    Guid UserId,
    Guid LoginEventId,
    DateTime Timestamp);
