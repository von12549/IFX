namespace IFX.Modules.Auth.Domain.Users.Events;

public record UserSyncedDomainEvent(
    Guid UserId,
    DateTime SyncedAt);
