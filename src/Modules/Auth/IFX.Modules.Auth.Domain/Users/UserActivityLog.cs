using IFX.BuildingBlocks.Domain;
// ActivityType is in same namespace (IFX.Modules.Auth.Domain.Users)

namespace IFX.Modules.Auth.Domain.Users;

public class UserActivityLog : BaseEntity
{
    public Guid UserId { get; private set; }
    public ActivityType ActivityType { get; private set; }
    public string Description { get; private set; } = string.Empty;
    public DateTime Timestamp { get; private set; }
    public string IpAddress { get; private set; } = string.Empty;
    public string Metadata { get; private set; } = string.Empty;

    private UserActivityLog() { } // For EF Core

    public static UserActivityLog Create(
        Guid userId,
        ActivityType activityType,
        string description,
        string ipAddress,
        string metadata = "{}")
    {
        return new UserActivityLog
        {
            UserId = userId,
            ActivityType = activityType,
            Description = description,
            Timestamp = DateTime.UtcNow,
            IpAddress = ipAddress,
            Metadata = metadata
        };
    }
}
