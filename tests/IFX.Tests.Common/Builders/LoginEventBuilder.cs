using IFX.Modules.IAM.Domain.Identity;

namespace IFX.Tests.Common.Builders;

public class LoginEventBuilder
{
    private Guid _userId = Guid.NewGuid();
    private string _ipAddress = TestConstants.ValidIpAddress;
    private string _userAgent = TestConstants.ValidUserAgent;
    private bool _success = true;
    private string? _failureReason;

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

    public LoginEvent Build()
    {
        if (_success)
        {
            return LoginEvent.CreateSuccess(
                _userId,
                _ipAddress,
                _userAgent);
        }

        return LoginEvent.CreateFailure(
            _userId,
            _ipAddress,
            _userAgent,
            _failureReason ?? "Unknown failure");
    }
}
