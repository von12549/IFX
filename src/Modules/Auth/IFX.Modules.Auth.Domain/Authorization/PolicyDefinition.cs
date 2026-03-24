using IFX.Modules.Auth.Domain.Common;

namespace IFX.Modules.Auth.Domain.Authorization;

public class PolicyDefinition : BaseEntity, IAuditableEntity
{
    public Guid TenantId { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public string ResourceType { get; private set; } = string.Empty;
    public string Action { get; private set; } = string.Empty;
    public string ConditionsJson { get; private set; } = string.Empty;
    public bool IsActive { get; private set; }
    public Guid? CreatedById { get; private set; }
    public Guid? UpdatedById { get; private set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    private PolicyDefinition() { } // EF Core

    public static PolicyDefinition Create(
        Guid tenantId,
        string name,
        string resourceType,
        string action,
        string conditionsJson,
        Guid? createdById)
    {
        if (tenantId == Guid.Empty)
            throw new ArgumentException("TenantId must not be empty.", nameof(tenantId));
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Name must not be empty.", nameof(name));
        if (string.IsNullOrWhiteSpace(resourceType))
            throw new ArgumentException("ResourceType must not be empty.", nameof(resourceType));
        if (string.IsNullOrWhiteSpace(action))
            throw new ArgumentException("Action must not be empty.", nameof(action));
        if (string.IsNullOrWhiteSpace(conditionsJson))
            throw new ArgumentException("ConditionsJson must not be empty.", nameof(conditionsJson));

        return new PolicyDefinition
        {
            TenantId = tenantId,
            Name = name.Trim(),
            ResourceType = resourceType.Trim().ToLowerInvariant(),
            Action = action.Trim().ToLowerInvariant(),
            ConditionsJson = conditionsJson,
            IsActive = true,
            CreatedById = createdById,
            UpdatedById = createdById
        };
    }

    public void Update(string name, string conditionsJson, Guid? updatedById)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Name must not be empty.", nameof(name));
        if (string.IsNullOrWhiteSpace(conditionsJson))
            throw new ArgumentException("ConditionsJson must not be empty.", nameof(conditionsJson));

        Name = name.Trim();
        ConditionsJson = conditionsJson;
        UpdatedById = updatedById;
    }

    public void Deactivate() => IsActive = false;
}
