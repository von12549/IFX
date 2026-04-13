namespace IFX.Modules.CRM.Application.InvestmentAccounts.DTOs;

public record AdvisorLinkDto(
    Guid Id,
    Guid TenantId,
    Guid AdvisorPartyId,
    Guid InvestmentAccountId,
    decimal? RebateRate,
    string EffectiveDate,
    string? ExpiryDate,
    DateTime CreatedAt);
