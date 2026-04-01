using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Entities;

public class PartyInvestorRelationship
{
    public Guid PartyId { get; private set; }
    public Guid InvestorId { get; private set; }
    public Guid TenantId { get; private set; }
    public RelationshipType RelationshipType { get; private set; }
    public DateOnly EffectiveDate { get; private set; }
    public DateOnly? ExpiryDate { get; private set; }

    private PartyInvestorRelationship() { } // For EF Core

    public static PartyInvestorRelationship Create(Guid partyId, Guid investorId, Guid tenantId, RelationshipType relationshipType, DateOnly effectiveDate)
    {
        if (partyId == Guid.Empty)
            throw new ArgumentException("PartyId must be provided.", nameof(partyId));

        if (investorId == Guid.Empty)
            throw new ArgumentException("InvestorId must be provided.", nameof(investorId));

        if (tenantId == Guid.Empty)
            throw new ArgumentException("TenantId must be provided.", nameof(tenantId));

        return new PartyInvestorRelationship
        {
            PartyId = partyId,
            InvestorId = investorId,
            TenantId = tenantId,
            RelationshipType = relationshipType,
            EffectiveDate = effectiveDate
        };
    }
}
