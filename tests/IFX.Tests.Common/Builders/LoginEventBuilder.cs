using IFX.Modules.Auth.Domain.Entities;

namespace IFX.Tests.Common.Builders;

public class LoginEventBuilder
{
    private Guid _userId = Guid.NewGuid();
    private string _ipAddress = TestConstants.ValidIpAddress;
    private string _userAgent = TestConstants.ValidUserAgent;
    private bool _success = true;
    private string? _failureReason;
    private string? _cognitoSessionId;
    private string? _accessToken;
    private string? _refreshToken;
    private DateTime? _tokenExpiresAt;

    public LoginEventBuilder WithUserId(Guid userId)
    {
        _userId = userId;
        return this;
    }

    public LoginEventBuilder WithIpAddress(string ipAddress)
    {
        _ipAddress = ipAddress;
        return this;
    }

    public LoginEventBuilder WithUserAgent(string userAgent)
    {
        _userAgent = userAgent;
        return this;
    }

    public LoginEventBuilder AsSuccess()
    {
        _success = true;
        _failureReason = null;
        return this;
    }

    public LoginEventBuilder AsFailure(string reason)
    {
        _success = false;
        _failureReason = reason;
        return this;
    }

    public LoginEventBuilder WithCognitoSessionId(string sessionId)
    {
        _cognitoSessionId = sessionId;
        return this;
    }

    public LoginEventBuilder WithTokens(string accessToken, string refreshToken, DateTime expiresAt)
    {
        _accessToken = accessToken;
        _refreshToken = refreshToken;
        _tokenExpiresAt = expiresAt;
        return this;
    }

    public LoginEvent Build()
    {
        if (_success)
        {
            return LoginEvent.CreateSuccess(
                _userId,
                _ipAddress,
                _userAgent,
                _cognitoSessionId,
                _accessToken,
                _refreshToken,
                _tokenExpiresAt);
        }

        return LoginEvent.CreateFailure(
            _userId,
            _ipAddress,
            _userAgent,
            _failureReason ?? "Unknown failure");
    }
}
