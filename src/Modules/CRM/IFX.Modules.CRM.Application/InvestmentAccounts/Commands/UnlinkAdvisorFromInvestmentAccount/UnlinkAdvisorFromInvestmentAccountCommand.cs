using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.UnlinkAdvisorFromInvestmentAccount;

public record UnlinkAdvisorFromInvestmentAccountCommand(Guid InvestmentAccountId, Guid AdvisorPartyId) : ICommand<Result<Unit>, CrmTransactionOwner>;
