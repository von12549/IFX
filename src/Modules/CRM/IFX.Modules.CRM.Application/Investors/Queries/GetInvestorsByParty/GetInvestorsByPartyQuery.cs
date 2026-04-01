using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Investors.DTOs;
using MediatR;

namespace IFX.Modules.CRM.Application.Investors.Queries.GetInvestorsByParty;

public record GetInvestorsByPartyQuery(Guid PartyId) : IRequest<Result<List<InvestorDto>>>;
