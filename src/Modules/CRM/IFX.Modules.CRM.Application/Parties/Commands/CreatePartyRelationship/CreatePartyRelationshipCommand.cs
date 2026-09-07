using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.CRM.Application.Common;
using IFX.Modules.CRM.Domain.Enums;
using MediatR;

namespace IFX.Modules.CRM.Application.Parties.Commands.CreatePartyRelationship;

public record CreatePartyRelationshipCommand(
    Guid FromPartyId,
    Guid ToPartyId,
    PartyRelationshipType RelationshipType,
    DateOnly EffectiveDate) : ICommand<Result<Unit>, CrmTransactionOwner>;
