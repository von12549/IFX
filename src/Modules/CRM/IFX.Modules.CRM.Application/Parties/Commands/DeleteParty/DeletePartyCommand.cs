using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.Parties.Commands.DeleteParty;

public record DeletePartyCommand(Guid PartyId) : IRequest<Result<bool>>;
