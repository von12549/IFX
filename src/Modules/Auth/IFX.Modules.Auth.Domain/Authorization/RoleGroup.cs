using IFX.Modules.Auth.Domain.Common;

namespace IFX.Modules.Auth.Domain.Authorization;

public class RoleGroup : BaseEntity, IAuditableEntity
{
    public string Name { get; private set; } = string.Empty;
    public string Description { get; private set; } = string.Empty;
    public Guid TenantId { get; private set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    private readonly List<Role> _roles = new();
    public IReadOnlyCollection<Role> Roles => _roles.AsReadOnly();

    private RoleGroup() { } // For EF Core

    public static RoleGroup Create(string name, string description, Guid tenantId)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Role group name cannot be empty.", nameof(name));

        if (string.IsNullOrWhiteSpace(description))
            throw new ArgumentException("Description cannot be empty.", nameof(description));

        if (tenantId == Guid.Empty)
            throw new ArgumentException("TenantId must be provided.", nameof(tenantId));

        return new RoleGroup
        {
            Name = name.Trim(),
            Description = description.Trim(),
            TenantId = tenantId
        };
    }

    public void Update(string name, string description)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Role group name cannot be empty.", nameof(name));

        if (string.IsNullOrWhiteSpace(description))
            throw new ArgumentException("Description cannot be empty.", nameof(description));

        Name = name.Trim();
        Description = description.Trim();
    }

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
}
