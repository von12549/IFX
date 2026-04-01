using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Parties.DTOs;
using MediatR;

namespace IFX.Modules.CRM.Application.Parties.Queries.GetParties;

public record GetPartiesQuery : IRequest<Result<List<PartyDto>>>;
