namespace IFX.Modules.CRM.Presentation.Investors.Requests;

public record AddInvestorDocumentRequest(
    string DocumentType,
    string DocumentNumber,
    string IssueCountry,
    string? IssueState = null,
    string? IssueDate = null,
    string? ExpiryDate = null);
