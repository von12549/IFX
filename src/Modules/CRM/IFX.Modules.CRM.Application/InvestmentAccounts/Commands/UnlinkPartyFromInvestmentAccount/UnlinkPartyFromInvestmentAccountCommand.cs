using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.UnlinkPartyFromInvestmentAccount;

public record UnlinkPartyFromInvestmentAccountCommand(Guid InvestmentAccountId, Guid PartyId) : ICommand<Result<Unit>, CrmTransactionOwner>;
