namespace IFX.Modules.Registry.Abstractions.DTOs;

public record FundSummaryDto(
    Guid FundId,
    string FundCode,
    string FundName,
    string FundType,
    string BaseCurrency,
    string Status);
