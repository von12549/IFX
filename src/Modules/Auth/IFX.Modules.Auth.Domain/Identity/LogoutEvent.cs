using IFX.BuildingBlocks.Domain;

namespace IFX.Modules.Auth.Domain.Identity;

public class LogoutEvent : BaseEntity
{
    public Guid UserId { get; private set; }
    public DateTimeOffset LogoutTimestamp { get; private set; }
    public TimeSpan SessionDuration { get; private set; }
    public string IpAddress { get; private set; } = string.Empty;
    public string Reason { get; private set; } = string.Empty;

    private LogoutEvent() { } // For EF Core

    public static LogoutEvent Create(
        Guid userId,
        string ipAddress,
        DateTimeOffset loginTimestamp,
        string reason = "Manual")
    {
        var logoutTimestamp = DateTimeOffset.UtcNow;
        var sessionDuration = logoutTimestamp - loginTimestamp;

        return new LogoutEvent
        {
            UserId = userId,
            LogoutTimestamp = logoutTimestamp,
            SessionDuration = sessionDuration,
            IpAddress = ipAddress,
            Reason = reason
        };
    }
}
