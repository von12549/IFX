namespace IFX.Modules.Registry.Presentation.Funds.Requests;

public record UpdateFundRequest(
    string FundName,
    string FundType,
    string BaseCurrency,
    Guid? ProductId = null,
    bool ClearProduct = false);
