using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.LinkAdvisorToInvestmentAccount;

public record LinkAdvisorToInvestmentAccountCommand(
    Guid InvestmentAccountId,
    Guid AdvisorPartyId,
    DateOnly EffectiveDate,
    decimal? RebateRate) : ICommand<Result<Unit>, CrmTransactionOwner>;
