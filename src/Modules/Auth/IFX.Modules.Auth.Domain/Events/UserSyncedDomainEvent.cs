namespace IFX.Modules.Auth.Domain.Events;

public record UserSyncedDomainEvent(
    Guid UserId,
    DateTime SyncedAt);
