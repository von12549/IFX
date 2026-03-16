using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Domain.Common;
using IFX.Modules.Auth.Domain.Identity;

namespace IFX.Modules.Auth.Domain.Users;

public class User : BaseEntity, IAuditableEntity
{
    public bool IsActive { get; private set; }
    public Guid UserRoleId { get; private set; }
    public string DisplayName { get; private set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation properties
    public UserRole? UserRole { get; private set; }

    private readonly List<UserIdentity> _identities = new();
    public IReadOnlyCollection<UserIdentity> Identities => _identities.AsReadOnly();

    private readonly List<LoginEvent> _loginEvents = new();
    public IReadOnlyCollection<LoginEvent> LoginEvents => _loginEvents.AsReadOnly();

    private User() { } // For EF Core

    public static User Create(
        Guid userRoleId,
        string displayName,
        bool isActive = false)
    {
        var user = new User
        {
            UserRoleId = userRoleId,
            DisplayName = displayName,
            IsActive = isActive
        };

        return user;
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

    public void UpdateDisplayName(string displayName)
    {
        DisplayName = displayName;
    }
}
