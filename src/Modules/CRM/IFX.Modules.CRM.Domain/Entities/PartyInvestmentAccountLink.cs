using IFX.BuildingBlocks.Domain;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Entities;

public class PartyInvestmentAccountLink : BaseEntity, IAuditableEntity
{
    public Guid TenantId { get; private set; }
    public Guid PartyId { get; private set; }
    public Guid InvestmentAccountId { get; private set; }
    public InvestmentAccountRelationshipType RelationshipType { get; private set; }
    public decimal? OwnershipPercentage { get; private set; }
    public int? LinkOrder { get; private set; }
    public DateOnly EffectiveDate { get; private set; }
    public DateOnly? ExpiryDate { get; private set; }
    public Guid? CreatedBy { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }

    public Party Party { get; private set; } = null!;
    public InvestmentAccount InvestmentAccount { get; private set; } = null!;

    private PartyInvestmentAccountLink() { }

    public static PartyInvestmentAccountLink Create(
        Guid tenantId,
        Guid partyId,
        Guid investmentAccountId,
        InvestmentAccountRelationshipType relationshipType,
        DateOnly effectiveDate,
        decimal? ownershipPercentage = null,
        int? linkOrder = null)
    {
        if (tenantId == Guid.Empty) throw new ArgumentException("TenantId required.", nameof(tenantId));
        if (partyId == Guid.Empty) throw new ArgumentException("PartyId required.", nameof(partyId));
        if (investmentAccountId == Guid.Empty) throw new ArgumentException("InvestmentAccountId required.", nameof(investmentAccountId));

        return new PartyInvestmentAccountLink
        {
            TenantId = tenantId,
            PartyId = partyId,
            InvestmentAccountId = investmentAccountId,
            RelationshipType = relationshipType,
            EffectiveDate = effectiveDate,
            OwnershipPercentage = ownershipPercentage,
            LinkOrder = linkOrder
        };
    }

    public void Expire(DateOnly expiryDate) => ExpiryDate = expiryDate;
}
