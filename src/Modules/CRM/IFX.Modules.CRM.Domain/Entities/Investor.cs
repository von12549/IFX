using IFX.Modules.CRM.Domain.Common;
using IFX.Modules.CRM.Domain.Enums;

namespace IFX.Modules.CRM.Domain.Entities;

public class Investor : BaseEntity, IAuditableEntity
{
    public Guid TenantId { get; private set; }
    public string InvestorCode { get; private set; } = string.Empty;
    public string Name { get; private set; } = string.Empty;
    public InvestorType Type { get; private set; }
    public KycStatus KycStatus { get; private set; } = KycStatus.Pending;
    public DateTime? KycReviewedAt { get; private set; }
    public string ResidencyCountry { get; private set; } = string.Empty;
    public string TaxResidency { get; private set; } = string.Empty;
    public EntityStatus Status { get; private set; } = EntityStatus.Active;
    public Guid? CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    private Investor() { } // For EF Core

    public static Investor Create(Guid tenantId, string investorCode, string name, InvestorType type, string residencyCountry, string taxResidency)
    {
        if (tenantId == Guid.Empty)
            throw new ArgumentException("TenantId must be provided.", nameof(tenantId));

        if (string.IsNullOrWhiteSpace(investorCode))
            throw new ArgumentException("InvestorCode cannot be empty.", nameof(investorCode));

        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Name cannot be empty.", nameof(name));

        if (string.IsNullOrWhiteSpace(residencyCountry))
            throw new ArgumentException("ResidencyCountry cannot be empty.", nameof(residencyCountry));

        if (string.IsNullOrWhiteSpace(taxResidency))
            throw new ArgumentException("TaxResidency cannot be empty.", nameof(taxResidency));

        return new Investor
        {
            TenantId = tenantId,
            InvestorCode = investorCode.Trim(),
            Name = name.Trim(),
            Type = type,
            ResidencyCountry = residencyCountry.Trim().ToUpperInvariant(),
            TaxResidency = taxResidency.Trim().ToUpperInvariant(),
            KycStatus = KycStatus.Pending,
            Status = EntityStatus.Active
        };
    }

    public void Update(string name, InvestorType type, string residencyCountry, string taxResidency)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("Name cannot be empty.", nameof(name));

        if (string.IsNullOrWhiteSpace(residencyCountry))
            throw new ArgumentException("ResidencyCountry cannot be empty.", nameof(residencyCountry));

        if (string.IsNullOrWhiteSpace(taxResidency))
            throw new ArgumentException("TaxResidency cannot be empty.", nameof(taxResidency));

        Name = name.Trim();
        Type = type;
        ResidencyCountry = residencyCountry.Trim().ToUpperInvariant();
        TaxResidency = taxResidency.Trim().ToUpperInvariant();
    }

    public void UpdateKyc(KycStatus kycStatus)
    {
        KycStatus = kycStatus;
        KycReviewedAt = DateTime.UtcNow;
    }

    public void Close()
    {
        Status = EntityStatus.Closed;
    }
}
