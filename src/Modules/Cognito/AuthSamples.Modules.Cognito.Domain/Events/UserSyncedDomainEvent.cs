namespace AuthSamples.Modules.Cognito.Domain.Events;

public record UserSyncedDomainEvent(
    Guid UserId,
    DateTime SyncedAt);
