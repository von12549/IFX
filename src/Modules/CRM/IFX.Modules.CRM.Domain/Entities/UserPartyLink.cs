using IFX.BuildingBlocks.Domain;

namespace IFX.Modules.CRM.Domain.Entities;

public class UserPartyLink : BaseEntity, IAuditableEntity
{
    /// <summary>Value reference to auth.Users — no cross-schema FK constraint.</summary>
    public Guid UserId { get; private set; }
    public Guid PartyId { get; private set; }
    public Guid TenantId { get; private set; }
    public Guid? CreatedBy { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public Party Party { get; private set; } = null!;

    private UserPartyLink() { }

    public static UserPartyLink Create(Guid userId, Guid partyId, Guid tenantId)
    {
        if (userId == Guid.Empty) throw new ArgumentException("UserId required.", nameof(userId));
        if (partyId == Guid.Empty) throw new ArgumentException("PartyId required.", nameof(partyId));
        if (tenantId == Guid.Empty) throw new ArgumentException("TenantId required.", nameof(tenantId));

        return new UserPartyLink { UserId = userId, PartyId = partyId, TenantId = tenantId };
    }
}
