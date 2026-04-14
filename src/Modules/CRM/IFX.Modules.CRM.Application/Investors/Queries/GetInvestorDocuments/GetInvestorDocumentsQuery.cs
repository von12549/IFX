using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Investors.DTOs;
using MediatR;

namespace IFX.Modules.CRM.Application.Investors.Queries.GetInvestorDocuments;

public record GetInvestorDocumentsQuery(Guid InvestorId) : IRequest<Result<IReadOnlyList<InvestorDocumentDto>>>;
