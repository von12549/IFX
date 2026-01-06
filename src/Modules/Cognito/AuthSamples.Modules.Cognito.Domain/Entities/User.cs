using AuthSamples.Modules.Cognito.Domain.Common;
using AuthSamples.Modules.Cognito.Domain.ValueObjects;

namespace AuthSamples.Modules.Cognito.Domain.Entities;

public class User : BaseEntity, IAuditableEntity
{
    private string _cognitoUserId = string.Empty;
    private string _email = string.Empty;
    private CognitoUserId? _cognitoUserIdCache;
    private EmailAddress? _emailCache;

    public CognitoUserId CognitoUserId
    {
        get
        {
            if (_cognitoUserIdCache == null || _cognitoUserIdCache.Value != _cognitoUserId)
                _cognitoUserIdCache = CognitoUserId.Create(_cognitoUserId);
            return _cognitoUserIdCache;
        }
        private set
        {
            _cognitoUserId = value.Value;
            _cognitoUserIdCache = value;
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
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    private readonly List<LoginEvent> _loginEvents = new();
    public IReadOnlyCollection<LoginEvent> LoginEvents => _loginEvents.AsReadOnly();

    private User() { } // For EF Core

    public static User Create(
        CognitoUserId cognitoUserId,
        EmailAddress email,
        string username,
        string firstName,
        string lastName,
        string birthDate,
        string phoneNumber,
        Guid userRoleId)
    {
        var user = new User
        {
            CognitoUserId = cognitoUserId,
            Email = email,
            Username = username,
            FirstName = firstName,
            LastName = lastName,
            BirthDate = birthDate,
            PhoneNumber = phoneNumber,
            UserRoleId = userRoleId,
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
}
