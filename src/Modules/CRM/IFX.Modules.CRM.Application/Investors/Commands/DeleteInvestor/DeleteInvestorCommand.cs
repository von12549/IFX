using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.Investors.Commands.DeleteInvestor;

public record DeleteInvestorCommand(Guid InvestorId) : ICommand<Result<bool>, CrmTransactionOwner>;
