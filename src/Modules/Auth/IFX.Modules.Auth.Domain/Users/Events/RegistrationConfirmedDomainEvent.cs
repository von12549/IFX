namespace IFX.Modules.Auth.Domain.Users.Events;

public record RegistrationConfirmedDomainEvent(
    Guid UserId,
    string Email,
    DateTimeOffset Timestamp);
