using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.Parties.Commands.ExpirePartyRelationship;

public record ExpirePartyRelationshipCommand(Guid RelationshipId, DateOnly ExpiryDate) : IRequest<Result<Unit>>;
