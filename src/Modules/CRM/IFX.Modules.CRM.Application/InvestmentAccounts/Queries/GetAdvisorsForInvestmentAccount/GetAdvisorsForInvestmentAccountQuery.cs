using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.InvestmentAccounts.DTOs;
using MediatR;

namespace IFX.Modules.CRM.Application.InvestmentAccounts.Queries.GetAdvisorsForInvestmentAccount;

public record GetAdvisorsForInvestmentAccountQuery(Guid InvestmentAccountId) : IRequest<Result<IReadOnlyList<AdvisorLinkDto>>>;
