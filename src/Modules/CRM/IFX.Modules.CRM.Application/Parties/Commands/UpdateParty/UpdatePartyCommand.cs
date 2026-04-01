using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Application.Parties.DTOs;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.Parties.Commands.UpdateParty;

public record UpdatePartyCommand(Guid PartyId, string Name, PartyType Type) : IRequest<Result<PartyDto>>;
