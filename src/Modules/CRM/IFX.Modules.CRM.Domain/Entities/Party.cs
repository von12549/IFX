using IFX.Modules.CRM.Domain.Common;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Entities;

public class Party : BaseEntity, IAuditableEntity
{
    public Guid TenantId { get; private set; }
    public string PartyCode { get; private set; } = string.Empty;
    public string Name { get; private set; } = string.Empty;
    public PartyType Type { get; private set; }
    public EntityStatus Status { get; private set; } = EntityStatus.Active;
    public Guid? CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    private Party() { } // For EF Core

    public static Party Create(Guid tenantId, string partyCode, string name, PartyType type)
    {
        if (tenantId == Guid.Empty)
            throw new ArgumentException("TenantId must be provided.", nameof(tenantId));

        if (string.IsNullOrWhiteSpace(partyCode))
            throw new ArgumentException("PartyCode cannot be empty.", nameof(partyCode));

        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Name cannot be empty.", nameof(name));

        return new Party
        {
            TenantId = tenantId,
            PartyCode = partyCode.Trim(),
            Name = name.Trim(),
            Type = type,
            Status = EntityStatus.Active
        };
    }

    public void Update(string name, PartyType type)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Name cannot be empty.", nameof(name));

        Name = name.Trim();
        Type = type;
    }

    public void Close()
    {
        Status = EntityStatus.Closed;
    }
}
