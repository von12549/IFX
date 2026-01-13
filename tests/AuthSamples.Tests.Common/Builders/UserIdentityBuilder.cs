using AuthSamples.Modules.Auth.Domain.Entities;
using AuthSamples.Modules.Auth.Domain.ValueObjects;

namespace AuthSamples.Tests.Common.Builders;

public class UserIdentityBuilder
{
    private Guid _userId = Guid.NewGuid();
    private Guid _idpId = Guid.NewGuid();
    private string _issuer = TestConstants.IFXCognitoIssuer;
    private string _subject = TestConstants.ValidSubject;
    private string _email = TestConstants.ValidEmail;
    private string _firstName = TestConstants.ValidFirstName;
    private string _lastName = TestConstants.ValidLastName;
    private string _birthDate = TestConstants.ValidBirthDate;
    private string _phoneNumber = TestConstants.ValidPhoneNumber;
    private bool _emailVerified = false;
    private bool _phoneNumberVerified = false;

    public UserIdentityBuilder WithUserId(Guid userId)
    {
        _userId = userId;
        return this;
    }

    public UserIdentityBuilder WithIdpId(Guid idpId)
    {
        _idpId = idpId;
        return this;
    }

    public UserIdentityBuilder WithIssuer(string issuer)
    {
        _issuer = issuer;
        return this;
    }

    public UserIdentityBuilder WithSubject(string subject)
    {
        _subject = subject;
        return this;
    }

    public UserIdentityBuilder WithEmail(string email)
    {
        _email = email;
        return this;
    }

    public UserIdentityBuilder WithFirstName(string firstName)
    {
        _firstName = firstName;
        return this;
    }

    public UserIdentityBuilder WithLastName(string lastName)
    {
        _lastName = lastName;
        return this;
    }

    public UserIdentityBuilder WithBirthDate(string birthDate)
    {
        _birthDate = birthDate;
        return this;
    }

    public UserIdentityBuilder WithPhoneNumber(string phoneNumber)
    {
        _phoneNumber = phoneNumber;
        return this;
    }

    public UserIdentityBuilder EmailVerified()
    {
        _emailVerified = true;
        return this;
    }

    public UserIdentityBuilder PhoneNumberVerified()
    {
        _phoneNumberVerified = true;
        return this;
    }

    public UserIdentity Build() => UserIdentity.Create(
        _userId,
        _idpId,
        _issuer,
        Subject.Create(_subject),
        EmailAddress.Create(_email),
        _firstName,
        _lastName,
        _birthDate,
        _phoneNumber,
        _emailVerified,
        _phoneNumberVerified);
}
