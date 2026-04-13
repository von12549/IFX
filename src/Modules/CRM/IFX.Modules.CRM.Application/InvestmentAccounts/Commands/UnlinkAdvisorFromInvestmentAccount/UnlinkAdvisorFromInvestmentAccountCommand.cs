using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.UnlinkAdvisorFromInvestmentAccount;

public record UnlinkAdvisorFromInvestmentAccountCommand(Guid InvestmentAccountId, Guid AdvisorPartyId) : IRequest<Result<Unit>>;
