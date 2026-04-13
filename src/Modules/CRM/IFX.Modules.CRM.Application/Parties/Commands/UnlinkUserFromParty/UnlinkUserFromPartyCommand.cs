using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.Parties.Commands.UnlinkUserFromParty;

public record UnlinkUserFromPartyCommand(Guid UserId) : IRequest<Result<Unit>>;
