using AuthSamples.Modules.Auth.Domain.Entities;

namespace AuthSamples.Tests.Common.Builders;

public class EmailVerificationTokenBuilder
{
    private Guid _userIdentityId = Guid.NewGuid();
    private string _email = TestConstants.ValidEmail;
    private string _tokenHash = "default-token-hash";
    private string _code = "123456";
    private TimeSpan _validityPeriod = TimeSpan.FromMinutes(60);
    private bool _markAsUsed = false;

    public EmailVerificationTokenBuilder WithUserIdentityId(Guid userIdentityId)
    {
        _userIdentityId = userIdentityId;
        return this;
    }

    public EmailVerificationTokenBuilder WithEmail(string email)
    {
        _email = email;
        return this;
    }

    public EmailVerificationTokenBuilder WithTokenHash(string tokenHash)
    {
        _tokenHash = tokenHash;
        return this;
    }

    public EmailVerificationTokenBuilder WithCode(string code)
    {
        _code = code;
        return this;
    }

    public EmailVerificationTokenBuilder WithValidityPeriod(TimeSpan validityPeriod)
    {
        _validityPeriod = validityPeriod;
        return this;
    }

    public EmailVerificationTokenBuilder Expired()
    {
        _validityPeriod = TimeSpan.FromMinutes(-1);
        return this;
    }

    public EmailVerificationTokenBuilder Used()
    {
        _markAsUsed = true;
        return this;
    }

    public EmailVerificationToken Build()
    {
        var token = EmailVerificationToken.Create(
            _userIdentityId,
            _email,
            _tokenHash,
            _code,
            _validityPeriod);

        if (_markAsUsed)
        {
            token.MarkAsUsed();
        }

        return token;
    }
}
