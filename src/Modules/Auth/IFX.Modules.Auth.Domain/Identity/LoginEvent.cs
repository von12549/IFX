using IFX.BuildingBlocks.Domain;
// DeviceInfo is in same namespace (IFX.Modules.Auth.Domain.Identity)

namespace IFX.Modules.Auth.Domain.Identity;

public class LoginEvent : BaseEntity
{
    public Guid UserId { get; private set; }
    public DateTime LoginTimestamp { get; private set; }
    public bool Success { get; private set; }
    public string? FailureReason { get; private set; }
    public string IpAddress { get; private set; } = string.Empty;
    public DeviceInfo DeviceInfo { get; private set; } = null!;
    public string UserAgent { get; private set; } = string.Empty;
    public string? CognitoSessionId { get; private set; }
    public string? AccessToken { get; private set; }
    public string? RefreshToken { get; private set; }
    public DateTime? TokenExpiresAt { get; private set; }

    private LoginEvent() { } // For EF Core

    public static LoginEvent CreateSuccess(
        Guid userId,
        string ipAddress,
        string userAgent,
        string? cognitoSessionId = null,
        string? accessToken = null,
        string? refreshToken = null,
        DateTime? tokenExpiresAt = null)
    {
        return new LoginEvent
        {
            UserId = userId,
            LoginTimestamp = DateTime.UtcNow,
            Success = true,
            FailureReason = null,
            IpAddress = ipAddress,
            DeviceInfo = DeviceInfo.Parse(userAgent),
            UserAgent = userAgent,
            CognitoSessionId = cognitoSessionId,
            AccessToken = accessToken,
            RefreshToken = refreshToken,
            TokenExpiresAt = tokenExpiresAt
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
            LoginTimestamp = DateTime.UtcNow,
            Success = false,
            FailureReason = failureReason,
            IpAddress = ipAddress,
            DeviceInfo = DeviceInfo.Parse(userAgent),
            UserAgent = userAgent,
            CognitoSessionId = null,
            AccessToken = null,
            RefreshToken = null,
            TokenExpiresAt = null
        };
    }
}
