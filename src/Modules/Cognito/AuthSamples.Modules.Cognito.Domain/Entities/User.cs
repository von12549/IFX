using AuthSamples.Modules.Cognito.Domain.Common;
using AuthSamples.Modules.Cognito.Domain.ValueObjects;

namespace AuthSamples.Modules.Cognito.Domain.Entities;

public class User : BaseEntity, IAuditableEntity
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
    public string Username { get; private set; } = string.Empty;
    public string FirstName { get; private set; } = string.Empty;
    public string LastName { get; private set; } = string.Empty;
    public string PhoneNumber { get; private set; } = string.Empty;
    public string BirthDate { get; private set; } = string.Empty;
    public bool EmailVerified { get; private set; }
    public bool PhoneNumberVerified { get; private set; }
    public bool IsActive { get; private set; }
    public DateTime LastSyncedAt { get; private set; }
    public Guid UserRoleId { get; private set; }
    public UserRole? UserRole { get; private set; }
    public string Issuer { get; private set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    private readonly List<LoginEvent> _loginEvents = new();
    public IReadOnlyCollection<LoginEvent> LoginEvents => _loginEvents.AsReadOnly();

    private User() { } // For EF Core

    public static User Create(
        Subject subject,
        EmailAddress email,
        string username,
        string firstName,
        string lastName,
        string birthDate,
        string phoneNumber,
        Guid userRoleId,
        string issuer = "https://cognito-idp.ap-southeast-2.amazonaws.com/ap-southeast-2_adW7gmF5P")
    {
        var user = new User
        {
            Subject = subject,
            Email = email,
            Username = username,
            FirstName = firstName,
            LastName = lastName,
            BirthDate = birthDate,
            PhoneNumber = phoneNumber,
            UserRoleId = userRoleId,
            Issuer = issuer,
            EmailVerified = false,
            PhoneNumberVerified = false,
            IsActive = false, // Will be activated after confirmation
            LastSyncedAt = DateTime.UtcNow
        };

        return user;
    }

    public void UpdateFromCognito(
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
        PhoneNumber = phoneNumber;
        EmailVerified = emailVerified;
        PhoneNumberVerified = phoneNumberVerified;
        LastSyncedAt = DateTime.UtcNow;
    }

    public void Activate()
    {
        IsActive = true;
    }

    public void Deactivate()
    {
        IsActive = false;
    }

    public void AssignRole(Guid roleId)
    {
        UserRoleId = roleId;
    }

    public void UpdateProfile(
        string? username = null,
        string? firstName = null,
        string? lastName = null,
        string? phoneNumber = null)
    {
        // Only update fields that are provided (not null)
        if (username != null)
            Username = username;

        if (firstName != null)
            FirstName = firstName;

        if (lastName != null)
            LastName = lastName;

        if (phoneNumber != null)
            PhoneNumber = phoneNumber;
    }
}
