using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.Parties.Commands.ExpirePartyRelationship;

public record ExpirePartyRelationshipCommand(Guid RelationshipId, DateOnly ExpiryDate) : ICommand<Result<Unit>, CrmTransactionOwner>;
