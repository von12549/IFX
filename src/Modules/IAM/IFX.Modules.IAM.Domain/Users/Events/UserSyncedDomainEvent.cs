namespace IFX.Modules.IAM.Domain.Users.Events;

public record UserSyncedDomainEvent(
    Guid UserId,
    DateTime SyncedAt);
