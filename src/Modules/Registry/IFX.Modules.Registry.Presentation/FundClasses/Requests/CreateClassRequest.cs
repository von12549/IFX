namespace IFX.Modules.Registry.Presentation.FundClasses.Requests;

public record CreateClassRequest(
    string ClassCode,
    string ClassName,
    string Currency,
    string NavFrequency,
    decimal? MinInitialInvestment,
    decimal? ManagementFeeRate,
    decimal? PerformanceFeeRate);
