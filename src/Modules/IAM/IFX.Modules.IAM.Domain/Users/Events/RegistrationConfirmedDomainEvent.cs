namespace IFX.Modules.IAM.Domain.Users.Events;

public record RegistrationConfirmedDomainEvent(
    Guid UserId,
    string Email,
    DateTimeOffset Timestamp);
