using AuthSamples.Modules.Cognito.Domain.Common;
using AuthSamples.Modules.Cognito.Domain.ValueObjects;

namespace AuthSamples.Modules.Cognito.Domain.Entities;

public class User : BaseEntity, IAuditableEntity
{
    public CognitoUserId CognitoUserId { get; private set; } = null!;
    public EmailAddress Email { get; private set; } = null!;
    public string Username { get; private set; } = string.Empty;
    public string FirstName { get; private set; } = string.Empty;
    public string LastName { get; private set; } = string.Empty;
    public string? PhoneNumber { get; private set; }
    public bool EmailVerified { get; private set; }
    public bool PhoneNumberVerified { get; private set; }
    public bool IsActive { get; private set; }
    public DateTime LastSyncedAt { get; private set; }
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
        string? phoneNumber = null)
    {
        var user = new User
        {
            CognitoUserId = cognitoUserId,
            Email = email,
            Username = username,
            FirstName = firstName,
            LastName = lastName,
            PhoneNumber = phoneNumber,
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
}
