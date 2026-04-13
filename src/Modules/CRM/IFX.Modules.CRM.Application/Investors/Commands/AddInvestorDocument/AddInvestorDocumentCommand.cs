using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.Investors.Commands.AddInvestorDocument;

public record AddInvestorDocumentCommand(
    Guid InvestorId,
    DocumentType DocumentType,
    string DocumentNumber,
    string IssueCountry,
    string? IssueState,
    DateOnly? IssueDate,
    DateOnly? ExpiryDate) : IRequest<Result<Unit>>;
