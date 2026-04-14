namespace IFX.Modules.Registry.Abstractions.DTOs;

public record ClassSummaryDto(
    Guid ClassId,
    Guid FundId,
    string ClassCode,
    string ClassName,
    string Currency,
    string NavFrequency,
    string Status,
    bool IsOpenForSubscription);
