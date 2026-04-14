namespace IFX.Modules.CRM.Application.Investors.DTOs;

public class InvestorDto
{
    public Guid Id { get; init; }
    public Guid TenantId { get; init; }
    public Guid? PartyId { get; init; }
    public string InvestorCode { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public string LegalStructure { get; init; } = string.Empty;

    // KYC
    public string KycStatus { get; init; } = string.Empty;
    public DateTime? KycReviewedAt { get; init; }

    // Tax & Compliance
    public string? TaxResidencyCountry { get; init; }
    public string? TIN { get; init; }
    public string FatcaCrsStatus { get; init; } = string.Empty;
    public string? GIIN { get; init; }

    // AML
    public string AmlStatus { get; init; } = string.Empty;
    public bool? IsPEP { get; init; }
    public string? SourceOfWealth { get; init; }

    public string Status { get; init; } = string.Empty;
    public DateTime CreatedAt { get; init; }
    public DateTime UpdatedAt { get; init; }
}
