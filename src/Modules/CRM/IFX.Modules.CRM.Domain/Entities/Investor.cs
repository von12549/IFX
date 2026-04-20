using IFX.BuildingBlocks.Domain;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Entities;

public class Investor : BaseEntity, IAuditableEntity
{
    public Guid TenantId { get; private set; }
    public Guid? PartyId { get; private set; }
    public string InvestorCode { get; private set; } = string.Empty;
    public string Name { get; private set; } = string.Empty;
    public PartyLegalStructure LegalStructure { get; private set; }

    // KYC
    public KycStatus KycStatus { get; private set; } = KycStatus.Pending;
    public DateTimeOffset? KycReviewedAt { get; private set; }

    // Tax & Compliance
    public string? TaxResidencyCountry { get; private set; }
    public string? TIN { get; private set; }
    public FatcaCrsStatus FatcaCrsStatus { get; private set; } = FatcaCrsStatus.NotReviewed;
    public string? GIIN { get; private set; }

    // AML
    public AmlStatus AmlStatus { get; private set; } = AmlStatus.NotChecked;
    public string? AmlGatewayReference { get; private set; }
    public DateTimeOffset? AmlCheckedAt { get; private set; }
    public bool? IsPEP { get; private set; }
    public string? PepDetails { get; private set; }
    public string? SourceOfWealth { get; private set; }
    public int UnresolvedPepCount { get; private set; }
    public int UnresolvedSanctionCount { get; private set; }
    public int UnresolvedAdverseMediaCount { get; private set; }

    public EntityStatus Status { get; private set; } = EntityStatus.Active;
    public Guid? CreatedBy { get; set; }
    public Guid? UpdatedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }

    // Extension profiles (at most one non-null, matched by LegalStructure)
    public IndividualInvestorProfile? IndividualProfile { get; private set; }
    public CorporateInvestorProfile? CorporateProfile { get; private set; }
    public TrustInvestorProfile? TrustProfile { get; private set; }

    private Investor() { }

    public static Investor Create(
        Guid tenantId,
        string investorCode,
        string name,
        PartyLegalStructure legalStructure,
        string? taxResidencyCountry = null,
        Guid? partyId = null)
    {
        if (tenantId == Guid.Empty)
            throw new ArgumentException("TenantId must be provided.", nameof(tenantId));
        if (string.IsNullOrWhiteSpace(investorCode))
            throw new ArgumentException("InvestorCode cannot be empty.", nameof(investorCode));
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Name cannot be empty.", nameof(name));

        return new Investor
        {
            TenantId = tenantId,
            InvestorCode = investorCode.Trim(),
            Name = name.Trim(),
            LegalStructure = legalStructure,
            TaxResidencyCountry = taxResidencyCountry?.Trim().ToUpperInvariant(),
            PartyId = partyId,
            KycStatus = KycStatus.Pending,
            AmlStatus = AmlStatus.NotChecked,
            FatcaCrsStatus = FatcaCrsStatus.NotReviewed,
            Status = EntityStatus.Active
        };
    }

    public void Update(string name, string? taxResidencyCountry, string? tin, string? giin)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Name cannot be empty.", nameof(name));

        Name = name.Trim();
        TaxResidencyCountry = taxResidencyCountry?.Trim().ToUpperInvariant();
        TIN = tin?.Trim();
        GIIN = giin?.Trim();
    }

    public void LinkParty(Guid partyId)
    {
        if (partyId == Guid.Empty)
            throw new ArgumentException("PartyId must be provided.", nameof(partyId));
        PartyId = partyId;
    }

    public void UpdateKyc(KycStatus kycStatus)
    {
        KycStatus = kycStatus;
        KycReviewedAt = DateTimeOffset.UtcNow;
    }

    public void UpdateFatcaCrs(FatcaCrsStatus status, string? giin = null)
    {
        FatcaCrsStatus = status;
        GIIN = giin?.Trim();
    }

    public void UpdateAmlStatus(
        AmlStatus amlStatus,
        string? gatewayReference = null,
        bool? isPep = null,
        string? pepDetails = null,
        string? sourceOfWealth = null,
        int unresolvedPepCount = 0,
        int unresolvedSanctionCount = 0,
        int unresolvedAdverseMediaCount = 0)
    {
        AmlStatus = amlStatus;
        AmlGatewayReference = gatewayReference?.Trim();
        AmlCheckedAt = DateTimeOffset.UtcNow;
        IsPEP = isPep;
        PepDetails = pepDetails?.Trim();
        SourceOfWealth = sourceOfWealth?.Trim();
        UnresolvedPepCount = unresolvedPepCount;
        UnresolvedSanctionCount = unresolvedSanctionCount;
        UnresolvedAdverseMediaCount = unresolvedAdverseMediaCount;
    }

    public void Close()
    {
        Status = EntityStatus.Closed;
    }
}
