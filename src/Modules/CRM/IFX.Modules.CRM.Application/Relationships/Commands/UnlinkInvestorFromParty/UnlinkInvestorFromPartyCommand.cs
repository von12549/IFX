using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.Relationships.Commands.UnlinkInvestorFromParty;

public record UnlinkInvestorFromPartyCommand(Guid PartyId, Guid InvestorId, RelationshipType RelationshipType) : IRequest<Result<bool>>;
