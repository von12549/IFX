using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.LinkAdvisorToInvestmentAccount;

public record LinkAdvisorToInvestmentAccountCommand(
    Guid InvestmentAccountId,
    Guid AdvisorPartyId,
    DateOnly EffectiveDate,
    decimal? RebateRate) : IRequest<Result<Unit>>;
