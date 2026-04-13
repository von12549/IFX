using IFX.BuildingBlocks.Domain;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Entities;

public class PartyRoleAssignment : BaseEntity, IAuditableEntity
{
    public Guid TenantId { get; private set; }
    public Guid PartyId { get; private set; }
    public PartyFunctionalRole Role { get; private set; }
    public DateTimeOffset AssignedAt { get; private set; }
    public Guid AssignedBy { get; private set; }
    public Guid? CreatedBy { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation
    public Party Party { get; private set; } = null!;

    private PartyRoleAssignment() { }

    public static PartyRoleAssignment Assign(Guid tenantId, Guid partyId, PartyFunctionalRole role, Guid assignedBy)
    {
        if (tenantId == Guid.Empty)
            throw new ArgumentException("TenantId must be provided.", nameof(tenantId));
        if (partyId == Guid.Empty)
            throw new ArgumentException("PartyId must be provided.", nameof(partyId));
        if (assignedBy == Guid.Empty)
            throw new ArgumentException("AssignedBy must be provided.", nameof(assignedBy));

        return new PartyRoleAssignment
        {
            TenantId = tenantId,
            PartyId = partyId,
            Role = role,
            AssignedAt = DateTimeOffset.UtcNow,
            AssignedBy = assignedBy
        };
    }
}
