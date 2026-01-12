namespace AuthSamples.Modules.Auth.Domain.Events;

public record RegistrationConfirmedDomainEvent(
    Guid UserId,
    string Email,
    DateTime Timestamp);
