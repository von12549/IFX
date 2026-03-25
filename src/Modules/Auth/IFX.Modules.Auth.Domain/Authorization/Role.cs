using IFX.Modules.Auth.Domain.Common;

namespace IFX.Modules.Auth.Domain.Authorization;

public class Role : BaseEntity, IAuditableEntity
{
    public string Name { get; private set; } = string.Empty;
    public string Description { get; private set; } = string.Empty;
    public Guid TenantId { get; private set; }
    public Tenant Tenant { get; private set; } = null!;
    public Guid? CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    private readonly List<Permission> _permissions = new();
    public IReadOnlyCollection<Permission> Permissions => _permissions.AsReadOnly();

    private Role() { } // For EF Core

    public static Role Create(string name, string description, Guid tenantId)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Role name cannot be empty.", nameof(name));

        if (string.IsNullOrWhiteSpace(description))
            throw new ArgumentException("Description cannot be empty.", nameof(description));

        if (tenantId == Guid.Empty)
            throw new ArgumentException("TenantId must be provided.", nameof(tenantId));

        return new Role
        {
            Name = name.Trim(),
            Description = description.Trim(),
            TenantId = tenantId
        };
    }

    public void Update(string name, string description)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Role name cannot be empty.", nameof(name));

        if (string.IsNullOrWhiteSpace(description))
            throw new ArgumentException("Description cannot be empty.", nameof(description));

        Name = name.Trim();
        Description = description.Trim();
    }

    public void AddPermission(Permission permission)
    {
        if (!_permissions.Any(p => p.Id == permission.Id))
            _permissions.Add(permission);
    }

    public void RemovePermission(Guid permissionId)
    {
        var permission = _permissions.FirstOrDefault(p => p.Id == permissionId);
        if (permission != null)
            _permissions.Remove(permission);
    }
}
