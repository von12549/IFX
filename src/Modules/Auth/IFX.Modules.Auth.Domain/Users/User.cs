using IFX.Modules.Auth.Domain.Authorization;
using IFX.Modules.Auth.Domain.Common;
using IFX.Modules.Auth.Domain.Identity;

namespace IFX.Modules.Auth.Domain.Users;

public class User : BaseEntity, IAuditableEntity
{
    public bool IsActive { get; private set; }
    public string DisplayName { get; private set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    private readonly List<Role> _roles = new();
    public IReadOnlyCollection<Role> Roles => _roles.AsReadOnly();

    private readonly List<RoleGroup> _roleGroups = new();
    public IReadOnlyCollection<RoleGroup> RoleGroups => _roleGroups.AsReadOnly();

    private readonly List<UserIdentity> _identities = new();
    public IReadOnlyCollection<UserIdentity> Identities => _identities.AsReadOnly();

    private readonly List<LoginEvent> _loginEvents = new();
    public IReadOnlyCollection<LoginEvent> LoginEvents => _loginEvents.AsReadOnly();

    private User() { } // For EF Core

    public static User Create(string displayName, bool isActive = false)
    {
        return new User
        {
            DisplayName = displayName,
            IsActive = isActive
        };
    }

    public void Activate() => IsActive = true;

    public void Deactivate() => IsActive = false;

    public void UpdateDisplayName(string displayName) => DisplayName = displayName;

    public void AddRole(Role role)
    {
        if (!_roles.Any(r => r.Id == role.Id))
            _roles.Add(role);
    }

    public void RemoveRole(Guid roleId)
    {
        var role = _roles.FirstOrDefault(r => r.Id == roleId);
        if (role != null)
            _roles.Remove(role);
    }

    public void AddRoleGroup(RoleGroup group)
    {
        if (!_roleGroups.Any(g => g.Id == group.Id))
            _roleGroups.Add(group);
    }

    public void RemoveRoleGroup(Guid groupId)
    {
        var group = _roleGroups.FirstOrDefault(g => g.Id == groupId);
        if (group != null)
            _roleGroups.Remove(group);
    }
}
