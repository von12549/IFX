using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Parties.DTOs;
using MediatR;

namespace IFX.Modules.CRM.Application.Parties.Queries.GetPartyRelationships;

public record GetPartyRelationshipsQuery(Guid PartyId) : IRequest<Result<IReadOnlyList<PartyRelationshipDto>>>;
