using IFX.BuildingBlocks.Application.Commands;
using IFX.Modules.CRM.Application.Transactions;
using IFX.Modules.CRM.Application.Common;
using MediatR;

namespace IFX.Modules.CRM.Application.Parties.Commands.LinkUserToParty;

public record LinkUserToPartyCommand(Guid UserId, Guid PartyId) : ICommand<Result<Unit>, CrmTransactionOwner>;
