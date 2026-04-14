using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.Parties.Commands.AssignPartyRole;

public record AssignPartyRoleCommand(Guid PartyId, PartyFunctionalRole Role) : IRequest<Result<Unit>>;
