using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Investors.DTOs;
using MediatR;

namespace IFX.Modules.CRM.Application.Investors.Queries.GetInvestorById;

public record GetInvestorByIdQuery(Guid InvestorId) : IRequest<Result<InvestorDto>>;
