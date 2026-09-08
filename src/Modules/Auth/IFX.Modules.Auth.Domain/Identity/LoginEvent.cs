using IFX.BuildingBlocks.Domain;
// DeviceInfo is in same namespace (IFX.Modules.Auth.Domain.Identity)

namespace IFX.Modules.Auth.Domain.Identity;

public class LoginEvent : BaseEntity
{
    public Guid UserId { get; private set; }
    public DateTimeOffset LoginTimestamp { get; private set; }
    public bool Success { get; private set; }
    public string? FailureReason { get; private set; }
    public string IpAddress { get; private set; } = string.Empty;
    public DeviceInfo DeviceInfo { get; private set; } = null!;
    public string UserAgent { get; private set; } = string.Empty;
    private LoginEvent() { } // For EF Core

    public static LoginEvent CreateSuccess(
        Guid userId,
        string ipAddress,
        string userAgent)
    {
        return new LoginEvent
        {
            UserId = userId,
            LoginTimestamp = DateTimeOffset.UtcNow,
            Success = true,
            FailureReason = null,
            IpAddress = ipAddress,
            DeviceInfo = DeviceInfo.Parse(userAgent),
            UserAgent = userAgent
        };
    }

    public static LoginEvent CreateFailure(
        Guid userId,
        string ipAddress,
        string userAgent,
        string failureReason)
    {
        return new LoginEvent
        {
            UserId = userId,
            LoginTimestamp = DateTimeOffset.UtcNow,
            Success = false,
            FailureReason = failureReason,
            IpAddress = ipAddress,
            DeviceInfo = DeviceInfo.Parse(userAgent),
            UserAgent = userAgent
        };
    }
}
