using BaseEntity = IFX.BuildingBlocks.Domain.BaseEntity;
using IFX.Modules.IAM.Domain.Common;

namespace IFX.Modules.IAM.Domain.Tenancy;

public class Tenant : BaseEntity, IAuditableEntity
{
    public bool IsActive { get; private set; } = true;
    public void Activate() => IsActive = true;
    public void Deactivate() => IsActive = false;
    public string Name { get; private set; } = string.Empty;
    public string Description { get; private set; } = string.Empty;
    public Guid? CreatedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }

    private Tenant() { } // For EF Core

    public static Tenant Create(string name, string description)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Tenant name cannot be empty.", nameof(name));

        if (string.IsNullOrWhiteSpace(description))
            throw new ArgumentException("Description cannot be empty.", nameof(description));

        return new Tenant
        {
            Name = name.Trim(),
            Description = description.Trim()
        };
    }

    public void Update(string name, string description)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Tenant name cannot be empty.", nameof(name));

        if (string.IsNullOrWhiteSpace(description))
            throw new ArgumentException("Description cannot be empty.", nameof(description));

        Name = name.Trim();
        Description = description.Trim();
    }
}
