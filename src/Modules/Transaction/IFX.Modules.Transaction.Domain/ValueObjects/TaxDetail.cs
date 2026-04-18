namespace IFX.Modules.Transaction.Domain.ValueObjects;

public class TaxDetail
{
    public string Type { get; init; } = string.Empty;
    public decimal? Rate { get; init; }
    public decimal Amount { get; init; }
    public string Currency { get; init; } = string.Empty;
    public bool? ExemptionIndicator { get; init; }
    public string? ExemptionReason { get; init; }
}
