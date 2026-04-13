using IFX.BuildingBlocks.Domain;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Entities;

public class Party : BaseEntity, IAuditableEntity
{
    public Guid TenantId { get; private set; }
    public string PartyCode { get; private set; } = string.Empty;
    public string Name { get; private set; } = string.Empty;
    public PartyLegalStructure LegalStructure { get; private set; }
    public EntityStatus Status { get; private set; } = EntityStatus.Active;
    public Guid? CreatedBy { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation
    public ICollection<PartyRoleAssignment> RoleAssignments { get; private set; } = new List<PartyRoleAssignment>();

    private Party() { }

    public static Party Create(Guid tenantId, string partyCode, string name, PartyLegalStructure legalStructure)
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
            LegalStructure = legalStructure,
            Status = EntityStatus.Active
        };
    }

    public void Update(string name, PartyLegalStructure legalStructure)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Name cannot be empty.", nameof(name));

        Name = name.Trim();
        LegalStructure = legalStructure;
    }

    public void Close()
    {
        Status = EntityStatus.Closed;
    }
}
