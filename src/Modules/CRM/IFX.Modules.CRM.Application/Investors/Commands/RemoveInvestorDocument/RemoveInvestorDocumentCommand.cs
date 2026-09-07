using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.Investors.Commands.RemoveInvestorDocument;

public record RemoveInvestorDocumentCommand(Guid InvestorId, Guid DocumentId) : ICommand<Result<Unit>, CrmTransactionOwner>;
