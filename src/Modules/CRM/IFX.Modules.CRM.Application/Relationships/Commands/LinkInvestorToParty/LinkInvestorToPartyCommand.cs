using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.Relationships.Commands.LinkInvestorToParty;

public record LinkInvestorToPartyCommand(Guid PartyId, Guid InvestorId, RelationshipType RelationshipType, DateOnly EffectiveDate) : IRequest<Result<bool>>;
