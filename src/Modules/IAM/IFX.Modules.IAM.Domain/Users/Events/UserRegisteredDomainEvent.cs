namespace IFX.Modules.IAM.Domain.Users.Events;

public record UserRegisteredDomainEvent(
    Guid UserId,
    string Email,
    string Username,
    DateTimeOffset Timestamp);
