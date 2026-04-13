using IFX.BuildingBlocks.Domain;

namespace IFX.Modules.CRM.Domain.Entities;

public class TrustInvestorProfile : BaseEntity, IAuditableEntity
{
    public Guid InvestorId { get; private set; }
    public string? TrustType { get; private set; }
    public string? TrustDeedReference { get; private set; }
    public DateOnly? TrustEstablishedDate { get; private set; }
    public Guid? TrusteePartyId { get; private set; }
    public string? FrankieOneEntityId { get; private set; }
    public Guid? CreatedBy { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public Investor Investor { get; private set; } = null!;

    private TrustInvestorProfile() { }

    public static TrustInvestorProfile Create(
        Guid investorId,
        string? trustType = null,
        string? trustDeedReference = null,
        DateOnly? trustEstablishedDate = null,
        Guid? trusteePartyId = null,
        string? frankieOneEntityId = null)
    {
        if (investorId == Guid.Empty)
            throw new ArgumentException("InvestorId must be provided.", nameof(investorId));

        return new TrustInvestorProfile
        {
            InvestorId = investorId,
            TrustType = trustType?.Trim(),
            TrustDeedReference = trustDeedReference?.Trim(),
            TrustEstablishedDate = trustEstablishedDate,
            TrusteePartyId = trusteePartyId,
            FrankieOneEntityId = frankieOneEntityId?.Trim()
        };
    }

    public void Update(
        string? trustType, string? trustDeedReference,
        DateOnly? trustEstablishedDate, Guid? trusteePartyId, string? frankieOneEntityId)
    {
        TrustType = trustType?.Trim();
        TrustDeedReference = trustDeedReference?.Trim();
        TrustEstablishedDate = trustEstablishedDate;
        TrusteePartyId = trusteePartyId;
        FrankieOneEntityId = frankieOneEntityId?.Trim();
    }
}
