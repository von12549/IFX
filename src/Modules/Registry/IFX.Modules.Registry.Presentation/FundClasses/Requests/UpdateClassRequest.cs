namespace IFX.Modules.Registry.Presentation.FundClasses.Requests;

public record UpdateClassRequest(
    string ClassName,
    string Currency,
    string NavFrequency,
    decimal? MinInitialInvestment,
    decimal? ManagementFeeRate,
    decimal? PerformanceFeeRate);
