using IFX.Modules.Auth.Domain.Common;

namespace IFX.Modules.Auth.Domain.Entities;

public class UserRole : BaseEntity, IAuditableEntity
{
    public string RoleName { get; private set; } = string.Empty;
    public string Description { get; private set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    private UserRole() { } // For EF Core

    public static UserRole Create(string roleName, string description)
    {
        if (string.IsNullOrWhiteSpace(roleName))
            throw new ArgumentException("Role name cannot be empty.", nameof(roleName));

        if (string.IsNullOrWhiteSpace(description))
            throw new ArgumentException("Description cannot be empty.", nameof(description));

        var role = new UserRole
        {
            RoleName = roleName.Trim(),
            Description = description.Trim()
        };

        return role;
    }

    public void Update(string roleName, string description)
    {
        if (string.IsNullOrWhiteSpace(roleName))
            throw new ArgumentException("Role name cannot be empty.", nameof(roleName));

        if (string.IsNullOrWhiteSpace(description))
            throw new ArgumentException("Description cannot be empty.", nameof(description));

        RoleName = roleName.Trim();
        Description = description.Trim();
    }
}
