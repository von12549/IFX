namespace IFX.Modules.Registry.Application.FundClasses.DTOs;

public class FundClassDto
{
    public Guid Id { get; init; }
    public Guid FundId { get; init; }
    public Guid TenantId { get; init; }
    public string ClassCode { get; init; } = string.Empty;
    public string ClassName { get; init; } = string.Empty;
    public string Currency { get; init; } = string.Empty;
    public decimal? MinInitialInvestment { get; init; }
    public decimal? ManagementFeeRate { get; init; }
    public decimal? PerformanceFeeRate { get; init; }
    public string NavFrequency { get; init; } = string.Empty;
    public string Status { get; init; } = string.Empty;
    public bool IsOpenForSubscription { get; init; }
    public DateTime CreatedAt { get; init; }
    public DateTime UpdatedAt { get; init; }
}
