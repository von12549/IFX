using BaseEntity = IFX.BuildingBlocks.Domain.BaseEntity;
using IFX.Modules.IAM.Domain.Common;

namespace IFX.Modules.IAM.Domain.Access;

public class Permission : BaseEntity, IAuditableEntity
{
    public string Name { get; private set; } = string.Empty;
    public string Description { get; private set; } = string.Empty;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }

    private Permission() { } // For EF Core

    public static Permission Create(string name, string description)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Permission name cannot be empty.", nameof(name));

        if (string.IsNullOrWhiteSpace(description))
            throw new ArgumentException("Description cannot be empty.", nameof(description));

        return new Permission
        {
            Name = name.Trim(),
            Description = description.Trim()
        };
    }

    public void Update(string name, string description)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Permission name cannot be empty.", nameof(name));

        if (string.IsNullOrWhiteSpace(description))
            throw new ArgumentException("Description cannot be empty.", nameof(description));

        Name = name.Trim();
        Description = description.Trim();
    }
}
