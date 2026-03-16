namespace IFX.Modules.Auth.Domain.Users.Events;

public record UserRegisteredDomainEvent(
    Guid UserId,
    string Email,
    string Username,
    DateTime Timestamp);
