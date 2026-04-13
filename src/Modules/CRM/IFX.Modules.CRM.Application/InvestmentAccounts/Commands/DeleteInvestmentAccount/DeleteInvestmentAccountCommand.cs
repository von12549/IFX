using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Commands.DeleteInvestmentAccount;

public record DeleteInvestmentAccountCommand(Guid Id) : IRequest<Result<Unit>>;
