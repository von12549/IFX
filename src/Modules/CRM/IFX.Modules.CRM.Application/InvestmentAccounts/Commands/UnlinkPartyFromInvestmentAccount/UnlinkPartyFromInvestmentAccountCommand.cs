using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.UnlinkPartyFromInvestmentAccount;

public record UnlinkPartyFromInvestmentAccountCommand(Guid InvestmentAccountId, Guid PartyId) : IRequest<Result<Unit>>;
