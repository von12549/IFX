using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.InvestmentAccounts.DTOs;
using MediatR;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Queries.GetInvestmentAccountById;

public record GetInvestmentAccountByIdQuery(Guid Id) : IRequest<Result<InvestmentAccountDto>>;
