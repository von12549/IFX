using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.InvestmentAccounts.DTOs;
using MediatR;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Queries.GetInvestmentAccounts;

public record GetInvestmentAccountsQuery : IRequest<Result<IReadOnlyList<InvestmentAccountDto>>>;
