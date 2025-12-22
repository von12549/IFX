namespace AuthSamples.Modules.Cognito.Domain.Events;

public record RegistrationConfirmedDomainEvent(
    Guid UserId,
    string Email,
    DateTime Timestamp);
