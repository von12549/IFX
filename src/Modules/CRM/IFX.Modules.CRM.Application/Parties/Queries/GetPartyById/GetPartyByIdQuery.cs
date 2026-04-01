using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Parties.DTOs;
using MediatR;

namespace IFX.Modules.CRM.Application.Parties.Queries.GetPartyById;

public record GetPartyByIdQuery(Guid PartyId) : IRequest<Result<PartyDto>>;
