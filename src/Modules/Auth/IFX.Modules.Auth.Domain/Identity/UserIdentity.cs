using IFX.Modules.Auth.Domain.Common;
using IFX.Modules.Auth.Domain.ValueObjects;

namespace IFX.Modules.Auth.Domain.Entities;

public class UserIdentity : BaseEntity, IAuditableEntity
{
    private string _subject = string.Empty;
    private string _email = string.Empty;
    private Subject? _subjectCache;
    private EmailAddress? _emailCache;

    public Subject Subject
    {
        get
        {
            if (_subjectCache == null || _subjectCache.Value != _subject)
                _subjectCache = Subject.Create(_subject);
            return _subjectCache;
        }
        private set
        {
            _subject = value.Value;
            _subjectCache = value;
        }
    }

    public EmailAddress Email
    {
        get
        {
            if (_emailCache == null || _emailCache.Value != _email)
                _emailCache = EmailAddress.Create(_email);
            return _emailCache;
        }
        private set
        {
            _email = value.Value;
            _emailCache = value;
        }
    }

    public Guid UserId { get; private set; }
    public Guid IdpId { get; private set; }
    public string Issuer { get; private set; } = string.Empty;
    public string FirstName { get; private set; } = string.Empty;
    public string LastName { get; private set; } = string.Empty;
    public string PhoneNumber { get; private set; } = string.Empty;
    public string BirthDate { get; private set; } = string.Empty;
    public bool EmailVerified { get; private set; }
    public bool PhoneNumberVerified { get; private set; }
    public DateTime LastSyncedAt { get; private set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation properties
    public User? User { get; private set; }
    public Idp? Idp { get; private set; }

    private UserIdentity() { } // For EF Core

    public static UserIdentity Create(
        Guid userId,
        Guid idpId,
        string issuer,
        Subject subject,
        EmailAddress email,
        string firstName,
        string lastName,
        string birthDate,
        string phoneNumber,
        bool emailVerified,
        bool phoneNumberVerified)
    {
        var userIdentity = new UserIdentity
        {
            UserId = userId,
            IdpId = idpId,
            Issuer = issuer,
            Subject = subject,
            Email = email,
            FirstName = firstName,
            LastName = lastName,
            BirthDate = birthDate,
            PhoneNumber = phoneNumber,
            EmailVerified = emailVerified,
            PhoneNumberVerified = phoneNumberVerified,
            LastSyncedAt = DateTime.UtcNow
        };

        return userIdentity;
    }

    public void UpdateFromIdp(
        EmailAddress email,
        string firstName,
        string lastName,
        string? phoneNumber,
        bool emailVerified,
        bool phoneNumberVerified)
    {
        Email = email;
        FirstName = firstName;
        LastName = lastName;
        PhoneNumber = phoneNumber ?? string.Empty;
        EmailVerified = emailVerified;
        PhoneNumberVerified = phoneNumberVerified;
        LastSyncedAt = DateTime.UtcNow;
    }

    public void UpdateProfile(
        string? firstName = null,
        string? lastName = null,
        string? phoneNumber = null)
    {
        if (firstName != null) FirstName = firstName;
        if (lastName != null) LastName = lastName;
        if (phoneNumber != null) PhoneNumber = phoneNumber;
    }

    public bool UpdateEmail(EmailAddress newEmail)
    {
        if (Email.Value == newEmail.Value)
        {
            return false; // No change
        }

        Email = newEmail;
        EmailVerified = false; // Reset verification when email changes
        return true;
    }

    public void SetEmailVerified(bool verified)
    {
        EmailVerified = verified;
    }
}
