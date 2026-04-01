namespace IFX.Modules.Registry.Presentation.Funds.Requests;

public record CreateFundRequest(
    string FundCode,
    string FundName,
    string FundType,
    string BaseCurrency,
    string InceptionDate);
