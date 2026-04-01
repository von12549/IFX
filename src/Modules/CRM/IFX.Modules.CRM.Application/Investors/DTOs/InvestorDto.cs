namespace IFX.Modules.CRM.Application.Investors.DTOs;

public class InvestorDto
{
    public Guid Id { get; init; }
    public Guid TenantId { get; init; }
    public string InvestorCode { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public string Type { get; init; } = string.Empty;
    public string KycStatus { get; init; } = string.Empty;
    public DateTime? KycReviewedAt { get; init; }
    public string ResidencyCountry { get; init; } = string.Empty;
    public string TaxResidency { get; init; } = string.Empty;
    public string Status { get; init; } = string.Empty;
    public DateTime CreatedAt { get; init; }
    public DateTime UpdatedAt { get; init; }
}
