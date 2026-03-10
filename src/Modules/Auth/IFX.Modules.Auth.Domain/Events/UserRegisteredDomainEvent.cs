namespace IFX.Modules.Auth.Domain.Events;

public record UserRegisteredDomainEvent(
    Guid UserId,
    string Email,
    string Username,
    DateTime Timestamp);
