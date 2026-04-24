namespace IFX.Modules.CRM.Application.Investors.DTOs;

public record InvestorDocumentDto(
    Guid Id,
    Guid InvestorId,
    Guid TenantId,
    string DocumentType,
    string DocumentNumber,
    string IssueCountry,
    string? IssueState,
    string? IssueDate,
    string? ExpiryDate,
    DateTimeOffset CreatedAt);
