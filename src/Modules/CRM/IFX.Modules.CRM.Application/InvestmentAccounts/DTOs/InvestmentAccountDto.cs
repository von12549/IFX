namespace IFX.Modules.CRM.Application.InvestmentAccounts.DTOs;

public record InvestmentAccountDto(
    Guid Id,
    Guid TenantId,
    string AccountNumber,
    string AccountType,
    string Status,
    DateOnly? CertificateDate,
    DateTime CreatedAt,
    DateTime UpdatedAt);
