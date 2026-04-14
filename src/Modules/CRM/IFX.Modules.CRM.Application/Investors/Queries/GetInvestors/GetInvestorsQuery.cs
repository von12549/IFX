using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Investors.DTOs;
using MediatR;

namespace IFX.Modules.CRM.Application.Investors.Queries.GetInvestors;

public record GetInvestorsQuery : IRequest<Result<List<InvestorDto>>>;
