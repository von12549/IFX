using IFX.BuildingBlocks.Domain;

namespace IFX.Modules.CRM.Domain.Entities;

public class AdvisorInvestmentAccountLink : BaseEntity, IAuditableEntity
{
    public Guid TenantId { get; private set; }
    public Guid AdvisorPartyId { get; private set; }
    public Guid InvestmentAccountId { get; private set; }
    public decimal? RebateRate { get; private set; }
    public DateOnly EffectiveDate { get; private set; }
    public DateOnly? ExpiryDate { get; private set; }
    public Guid? CreatedBy { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public Party AdvisorParty { get; private set; } = null!;
    public InvestmentAccount InvestmentAccount { get; private set; } = null!;

    private AdvisorInvestmentAccountLink() { }

    public static AdvisorInvestmentAccountLink Create(
        Guid tenantId,
        Guid advisorPartyId,
        Guid investmentAccountId,
        DateOnly effectiveDate,
        decimal? rebateRate = null)
    {
        if (tenantId == Guid.Empty) throw new ArgumentException("TenantId required.", nameof(tenantId));
        if (advisorPartyId == Guid.Empty) throw new ArgumentException("AdvisorPartyId required.", nameof(advisorPartyId));
        if (investmentAccountId == Guid.Empty) throw new ArgumentException("InvestmentAccountId required.", nameof(investmentAccountId));
        if (rebateRate.HasValue && (rebateRate < 0 || rebateRate > 100))
            throw new ArgumentException("RebateRate must be between 0 and 100.", nameof(rebateRate));

        return new AdvisorInvestmentAccountLink
        {
            TenantId = tenantId,
            AdvisorPartyId = advisorPartyId,
            InvestmentAccountId = investmentAccountId,
            EffectiveDate = effectiveDate,
            RebateRate = rebateRate
        };
    }

    public void Expire(DateOnly expiryDate) => ExpiryDate = expiryDate;

    public bool IsActive(DateOnly asOf) =>
        EffectiveDate <= asOf && (ExpiryDate == null || ExpiryDate >= asOf);
}
