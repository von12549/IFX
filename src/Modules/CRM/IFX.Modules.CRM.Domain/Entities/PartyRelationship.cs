using IFX.BuildingBlocks.Domain;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Entities;

public class PartyRelationship : BaseEntity, IAuditableEntity
{
    public Guid TenantId { get; private set; }
    public Guid FromPartyId { get; private set; }
    public Guid ToPartyId { get; private set; }
    public PartyRelationshipType RelationshipType { get; private set; }
    public DateOnly EffectiveDate { get; private set; }
    public DateOnly? ExpiryDate { get; private set; }
    public Guid? CreatedBy { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public Party FromParty { get; private set; } = null!;
    public Party ToParty { get; private set; } = null!;

    private PartyRelationship() { }

    public static PartyRelationship Create(
        Guid tenantId,
        Guid fromPartyId,
        Guid toPartyId,
        PartyRelationshipType relationshipType,
        DateOnly effectiveDate)
    {
        if (tenantId == Guid.Empty) throw new ArgumentException("TenantId required.", nameof(tenantId));
        if (fromPartyId == Guid.Empty) throw new ArgumentException("FromPartyId required.", nameof(fromPartyId));
        if (toPartyId == Guid.Empty) throw new ArgumentException("ToPartyId required.", nameof(toPartyId));
        if (fromPartyId == toPartyId) throw new ArgumentException("FromPartyId and ToPartyId must differ.");

        return new PartyRelationship
        {
            TenantId = tenantId,
            FromPartyId = fromPartyId,
            ToPartyId = toPartyId,
            RelationshipType = relationshipType,
            EffectiveDate = effectiveDate
        };
    }

    public void Expire(DateOnly expiryDate) => ExpiryDate = expiryDate;

    public bool IsActive(DateOnly asOf) =>
        EffectiveDate <= asOf && (ExpiryDate == null || ExpiryDate >= asOf);
}
