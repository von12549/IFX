using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.DeleteInvestmentAccount;

public record DeleteInvestmentAccountCommand(Guid Id) : ICommand<Result<Unit>, CrmTransactionOwner>;
