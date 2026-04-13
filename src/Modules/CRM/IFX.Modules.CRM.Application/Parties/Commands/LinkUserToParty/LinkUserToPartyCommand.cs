using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.Parties.Commands.LinkUserToParty;

public record LinkUserToPartyCommand(Guid UserId, Guid PartyId) : IRequest<Result<Unit>>;
